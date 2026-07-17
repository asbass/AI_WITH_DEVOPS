import os
import logging
import threading
import time
import asyncio
import requests
from openai import OpenAI
from kubernetes import client, config
from telegram import Update
from telegram.ext import ApplicationBuilder, ContextTypes, MessageHandler, filters

# Cấu hình Logging để dễ debug
logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

# Cấu hình AI Client
client_ai = OpenAI(api_key=os.getenv("OPENROUTER_API_KEY"), base_url="https://openrouter.ai/api/v1")
MODEL_ID = "meta-llama/llama-3.1-8b-instruct"

# Cấu hình K8s Client
try:
    config.load_incluster_config()
except config.ConfigException:
    config.load_kube_config() # Hỗ trợ test local nếu cần

apps_v1 = client.AppsV1Api()
core_v1 = client.CoreV1Api()

# Biến toàn cục lưu giữ Event Loop chính của Bot để Thread phụ có thể ké luồng gửi tin nhắn
main_event_loop = None

# --- CÁC CÔNG CỤ (TOOLS) ---

def query_5xx_rate():
    possible_urls = [
        "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090",
        "http://prometheus-operated.monitoring.svc.cluster.local:9090",
        "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:8080"
    ]
    query = 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100'
    
    for url in possible_urls:
        try:
            response = requests.get(f"{url}/api/v1/query", params={"query": query}, timeout=3)
            if response.status_code == 200:
                data = response.json()
                results = data.get('data', {}).get('result', [])
                return f"Tỉ lệ lỗi 5xx ({url.split(':')[2]}): {float(results[0]['value'][1]):.2f}%" if results else "0% lỗi"
        except:
            continue
    return "Không thể kết nối Prometheus (thử 9090 và 8080 đều lỗi)."


def rollback_deployment(to_image=None):
    """
    Nếu truyền to_image: Cập nhật trực tiếp sang image đó.
    Nếu KHÔNG truyền to_image: Tự động tìm image của phiên bản ổn định (Revision) liền trước đó để undo.
    """
    try:
        deploy = apps_v1.read_namespaced_deployment(name="app", namespace="app")
        container_name = deploy.spec.template.spec.containers[0].name

        if to_image:
            target_image = to_image
            msg_prefix = f"✅ Đã rollback deployment 'app' sang {target_image} thành công!"
        else:
            # Thuật toán chuẩn tìm ReplicaSet cũ của Deployment
            rs_list = apps_v1.list_namespaced_replica_set(namespace="app")
            
            # Lọc các ReplicaSet thực sự thuộc về deployment "app" thông qua owner_references
            valid_rs = []
            for rs in rs_list.items:
                if rs.metadata.owner_references:
                    for owner in rs.metadata.owner_references:
                        if owner.kind == "Deployment" and owner.name == "app":
                            valid_rs.append(rs)
            
            # Sắp xếp các ReplicaSet theo số thứ tự Revision giảm dần
            sorted_rs = sorted(
                valid_rs, 
                key=lambda x: int(x.metadata.annotations.get("deployment.kubernetes.io/revision", 0)) if x.metadata.annotations else 0, 
                reverse=True
            )
            
            if len(sorted_rs) < 2:
                return "❌ Không tìm thấy lịch sử phiên bản trước đó để tự động rollback!"
            
            # sorted_rs[0] là bản hiện tại đang lỗi, sorted_rs[1] là bản ổn định ngay trước đó
            target_image = sorted_rs[1].spec.template.spec.containers[0].image
            msg_prefix = f"✅ Tự động phát hiện và lùi 'app' về phiên bản cũ thành công! Image: {target_image}"

        # Tiến hành cập nhật Deployment cấu hình mới
        patch_body = {
            "spec": {
                "template": {
                    "spec": {
                        "containers": [{"name": container_name, "image": target_image}]
                    }
                }
            }
        }
        apps_v1.patch_namespaced_deployment(name="app", namespace="app", body=patch_body)
        return msg_prefix
        
    except Exception as e: 
        return f"❌ Rollback thất bại: {str(e)}"


def get_pod_logs(pod_name="app"):
    try:
        if pod_name == "app":
            pods = core_v1.list_namespaced_pod(namespace="app")
            if pods.items:
                pod_name = pods.items[0].metadata.name
            else:
                return "❌ Không tìm thấy bất kỳ Pod nào trong namespace 'app'"

        logs = core_v1.read_namespaced_pod_log(name=pod_name, namespace="app", tail_lines=20)
        return f"📜 Log cuối của {pod_name}:\n{logs}"
    except Exception as e:
        return f"❌ Không thể đọc log của {pod_name}: {str(e)}"


def check_pod_status():
    try:
        pods = core_v1.list_namespaced_pod("app")
        status_report = ""
        for pod in pods.items:
            status = pod.status.phase
            detail_msg = ""
            if pod.status.container_statuses:
                for cs in pod.status.container_statuses:
                    if cs.state.waiting:
                        status = cs.state.waiting.reason  
                        detail_msg = f" ({cs.state.waiting.message})" if cs.state.waiting.message else ""
            status_report += f"Pod {pod.metadata.name}: {status}{detail_msg}\n"
        return status_report
    except Exception as e:
        return f"❌ Lỗi check_pod_status: {str(e)}"


def check_resource_usage():
    url = "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
    query = 'sum(container_memory_working_set_bytes{pod=~"app-.*"}) / 1024 / 1024'
    try:
        response = requests.get(f"{url}/api/v1/query", params={"query": query}, timeout=3)
        data = response.json()
        val = data['data']['result'][0]['value'][1]
        return f"🚀 Mức tiêu thụ RAM hiện tại: {float(val):.2f} MB"
    except:
        return "❌ Không lấy được dữ liệu RAM từ Prometheus."

# --- LOGIC AGENT ---

def run_sre_agent(user_prompt):
    system_instruction = """
    Bạn là một chuyên gia SRE (Site Reliability Engineering) thông thái. 
    Bạn có quyền truy cập vào các công cụ sau:
    1. query_5xx_rate: Kiểm tra tỉ lệ lỗi 5xx của hệ thống.
    2. rollback_deployment: Rollback deployment về bản cũ (Có thể truyền tên image cụ thể nếu người dùng yêu cầu).
    3. check_resource_usage: Kiểm tra tài nguyên RAM.
    4. get_pod_logs: Đọc log pod.
    5. check_pod_status: Kiểm tra hạ tầng và phát hiện ImagePullBackOff.

    Hãy phân tích kỹ yêu cầu của người dùng để chọn và gọi đúng công cụ.
    """
    
    messages = [
        {"role": "system", "content": system_instruction},
        {"role": "user", "content": user_prompt}
    ]
    
    tools = [
        {"type": "function", "function": {"name": "query_5xx_rate", "description": "Kiểm tra tỉ lệ lỗi 5xx"}},
        {
            "type": "function", 
            "function": {
                "name": "rollback_deployment", 
                "description": "Rollback deployment về image ổn định. Có thể truyền tham số image mong muốn.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "to_image": {"type": "string", "description": "Tên image đầy đủ kèm tag (Không bắt buộc)"}
                    }
                }
            }
        },
        {"type": "function", "function": {"name": "check_resource_usage", "description": "Kiểm tra mức tiêu thụ RAM của app"}},
        {"type": "function", "function": {"name": "get_pod_logs", "description": "Đọc log của pod. Dùng 'app' làm mặc định."}},
        {"type": "function", "function": {"name": "check_pod_status", "description": "Kiểm tra hạ tầng, trạng thái Pod"}}
    ]
    
    try:
        response = client_ai.chat.completions.create(model=MODEL_ID, messages=messages, tools=tools, tool_choice="auto")
        msg = response.choices[0].message
        
        if msg.tool_calls:
            import json
            results = []
            for tool_call in msg.tool_calls:
                func_name = tool_call.function.name
                args = json.loads(tool_call.function.arguments) if tool_call.function.arguments else {}
                
                if func_name == "query_5xx_rate":
                    results.append(query_5xx_rate())
                elif func_name == "rollback_deployment":
                    results.append(rollback_deployment(to_image=args.get("to_image")))
                elif func_name == "check_resource_usage":
                    results.append(check_resource_usage()) 
                elif func_name == "get_pod_logs":
                    results.append(get_pod_logs())
                elif func_name == "check_pod_status": 
                    results.append(check_pod_status())
            return "\n".join(results)
            
        return msg.content if msg.content else "Agent chưa hiểu yêu cầu của bạn."
    except Exception as e:
        return f"❌ Lỗi Agent xử lý: {str(e)}"

# --- LUỒNG GIÁM SÁT CHỦ ĐỘNG (WATCHDOG THREAD) ---

def send_telegram_message_safely(bot, chat_id, text):
    """Hàm bổ trợ giúp đẩy tin nhắn từ Thread phụ về Main Event Loop của Telegram một cách an toàn"""
    if main_event_loop and main_event_loop.is_running():
        asyncio.run_coroutine_threadsafe(bot.send_message(chat_id=chat_id, text=text), main_event_loop)
    else:
        logger.error("Event loop chính chưa sẵn sàng. Không thể gửi tin nhắn Telegram.")

def monitor_loop(bot_app):
    print("Vòng lặp giám sát (Watchdog) đã khởi động!")
    CHAT_ID = "5350035230"
    
    while True:
        try:
            # --- 1. KIỂM TRA LỖI TẦNG TRAFFIC (5XX) ---
            rate_str = query_5xx_rate()
            if "lỗi" in rate_str and "0%" not in rate_str and "Không thể" not in rate_str:
                try:
                    rate_val = float(rate_str.split(":")[1].replace("%", "").strip())
                    if rate_val > 5.0:
                        msg = f"🚨 CẢNH BÁO TRAFFIC: Tỉ lệ lỗi 5xx đang là {rate_val}%. Hệ thống có dấu hiệu quá tải!"
                        print(msg)
                        send_telegram_message_safely(bot_app.bot, CHAT_ID, msg)
                        
                        log_report = get_pod_logs()
                        send_telegram_message_safely(bot_app.bot, CHAT_ID, f"🕵️ RCA Log nhanh:\n{log_report}")
                except Exception as parse_err:
                    print(f"Lỗi parse số %: {parse_err}")

            # --- 2. KIỂM TRA LỖI TẦNG HẠ TẦNG (POD STATUS) ---
            pod_status_report = check_pod_status()
            if any(err in pod_status_report for err in ["ImagePullBackOff", "ErrImagePull", "CrashLoopBackOff", "Lỗi", "Error"]):
                msg_infra = f"🚨 CẢNH BÁO HẠ TẦNG:\n{pod_status_report}\n👉 Phát hiện trạng thái bất thường!"
                print(msg_infra)
                send_telegram_message_safely(bot_app.bot, CHAT_ID, msg_infra)
                
                # CHỈ đọc log nếu không phải là lỗi kéo Image (để tránh lỗi API 400 rác)
                if "ImagePull" not in pod_status_report:
                    log_report = get_pod_logs()
                    send_telegram_message_safely(bot_app.bot, CHAT_ID, f"🕵️ RCA Log nhanh hệ thống:\n{log_report}")
                else:
                    send_telegram_message_safely(bot_app.bot, CHAT_ID, "💡 Nhắc nhở SRE: Lỗi kéo Image, vui lòng kiểm tra lại tên Image hoặc cấu hình ImagePullSecrets.")

        except Exception as e:
            print(f"Lỗi vòng lặp giám sát: {e}")
        
        time.sleep(60)

# --- KHỞI CHẠY BOT ---

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    response = run_sre_agent(update.message.text)
    await update.message.reply_text(response)

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    logger.error(msg="Exception while handling an update:", exc_info=context.error)

if __name__ == "__main__":
    # Thay Token Telegram của bạn vào đây
    app = ApplicationBuilder().token("8797427567:AAFlB7lRVN-J0ZYwowqbciZg1ihED0--KYU").build()
    
    # Đăng ký các handler xử lý tin nhắn chat
    app.add_handler(MessageHandler(filters.TEXT & (~filters.COMMAND), handle_message))
    app.add_error_handler(error_handler)
    
    # Bắt lấy Event Loop chính ngay khi khởi tạo ứng dụng Telegram để share cho luồng phụ
    main_event_loop = asyncio.get_event_loop()
    
    # Khởi tạo Thread phụ chạy vòng lặp Watchdog ngầm
    monitor_thread = threading.Thread(target=monitor_loop, args=(app,), daemon=True)
    monitor_thread.start()
    
    print("Agent SRE đã sẵn sàng kích hoạt và lắng nghe...")
    app.run_polling()
