killall VBoxClient
VBoxClient --clipboard


aws eks update-kubeconfig --region ap-southeast-1 --name DE00175-eks
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/aws/deploy.yaml
kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=180s
kubectl apply -f sc.yaml
kubectl create namespace jenkins
kubectl apply -f pvc.yaml

kubectl apply -f jenkins-deploy.yaml
#kubectl apply -f app.yaml --namespace=app --validate=false
# Lấy địa chỉ Jenkins	
kubectl -n jenkins get svc jenkins-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Lấy địa chỉ Nginx Ingress (App)
kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl exec -it $(kubectl get pods -n jenkins -l app=jenkins -o name) -n jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword

kubectl port-forward svc/jenkins-service 8080:80 -n jenkins
ssh -i build-machine-key.pem ubuntu@13.212.62.45

kubectl get svc -n jenkins



Bước 7 — Đăng ký EC2 làm JNLP agent
Trên Jenkins UI:

Manage Jenkins → Nodes → New Node:
Node name: ec2-build, Type: Permanent Agent → Create.
Form node:
Remote root directory: /home/ubuntu/jenkins
Labels: ec2-build
Launch method: Launch agent by connecting it to the controller
Save.
Click node ec2-build → copy đoạn lệnh java -jar agent.jar ... (có chứa SECRET).




# Tải agent.jar và chạy (paste lệnh từ Jenkins UI)
mkdir -p ~/jenkins && cd ~/jenkins

JENKINS_URL="http://a9b47416fe6c947ffb1f50b8b5ac36c8-278539623.ap-southeast-1.elb.amazonaws.com"
curl -sO http://a9b47416fe6c947ffb1f50b8b5ac36c8-278539623.ap-southeast-1.elb.amazonaws.com/jnlpJars/agent.jar
java -jar agent.jar -url "${JENKINS_URL}/" -secret f33fe6236370a9b4d3cf9f2738efd439f3f067aa3b6252bc6962964542c6301d -name worker -webSocket -workDir "/home/ubuntu/jenkins"


# 1. ACCOUNT_ID: Giữ nguyên nếu bạn đang ở đúng tài khoản đó
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 2. REGION: Giữ nguyên
REGION=ap-southeast-1

# 3. REPO: Phải khớp với tên repo trên ECR của bạn
# Trong log lỗi ban đầu bạn để là: 891920435433.dkr.ecr.ap-southeast-1.amazonaws.com/de00175-app
REPO=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/de00175-app

# 4. PATH Terraform: Kiểm tra xem thư mục chứa file .tf của bạn là gì
# Nếu bạn đang để file main.tf ở thư mục gốc hoặc tên khác, hãy sửa lại cho đúng
RDS_ENDPOINT=$(terraform output -raw mysql_endpoint)
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPO
#docker build -t $REPO:v1 
#docker push $REPO:v1
sed \
  -e "s|REPLACE_WITH_RDS_ENDPOINT|$RDS_ENDPOINT|g" \
  -e 's|REPLACE_WITH_PASSWORD|Tai123456789|g' \
  -e "s|REPLACE_WITH_ECR_URI:latest|$REPO:latest|g" \
  app.yaml > app_final.yaml

# Sau đó apply file đã được thay thế
kubectl apply -f app_final.yaml --namespace=app

[Hạ tầng K8s / Prometheus Cluster]
│
▼ (Quét tự động mỗi 60s qua Watchdog Thread)
[Monitor Loop] ──(Phát hiện sự cố)──► [Bắn cảnh báo Telegram + RCA Log thật]
│
▼ (Admin nhận tin nhắn & ra lệnh cứu hộ)
[User Chat trên Telegram] ────────────────► [Bộ não AI Agent (Llama 3.1 via OpenRouter)]
│
▼ (AI tự suy luận & chọn đúng Công cụ)
[Remediation Tool: Rollback với Watchdog]
│
▼ (Kiểm tra trạng thái Rollout thực tế)
[Hệ thống phục hồi thành công Xanh Mượt]


---

## ✨ Tính Năng Nổi Bật

### 1. Giám Sát Đa Tầng Chủ Động (Multi-Layer Observability Watchdog)
*   **Tầng Traffic (Prometheus Metrics):** Tự động tính toán tỉ lệ lỗi HTTP 5xx dựa trên PromQL: `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100`.
*   **Tầng Hạ Tầng (Kubernetes Core API):** Quét sâu vào trạng thái container để phát hiện ngay lập tức các lỗi nghiêm trọng như `ImagePullBackOff`, `CrashLoopBackOff`, `Error`.

### 2. Bộ Não AI Phân Tích Ngữ Cảnh (Cognitive Agent AI)
*   Sử dụng mô hình **Llama-3.1-8b-instruct** qua OpenRouter để hiểu ngôn ngữ tự nhiên từ Admin.
*   Tự động ánh xạ yêu cầu của người dùng để kích hoạt các hàm Python công cụ (`Function Calling`).

### 3. Công Cụ Thực Thi Chuẩn SRE (Production-Grade Execution Tools)
*   **Smart Log Collector:** Tự động tìm kiếm tên định danh chính xác của Pod dựa trên mã hash ngẫu nhiên của Deployment để kéo log RCA (Root Cause Analysis).
*   **Safe Rollback Engine with Rollout Status Watchdog:** Khi nhận lệnh Rollback, Agent không chỉ gửi patch bừa bãi. Nó sẽ "nín thở" giám sát trạng thái `ready_replicas` trong vòng 120s. Nếu bản rollback tiếp tục dính lỗi, nó sẽ lập tức chặn đứng và báo cáo trạng thái lỗi thực tế (chống hiện tượng *False Positive*).

---

## 📦 Cài Đặt Thành Phần Phụ Thuộc (K8s Cluster Prerequisites)

Để Agent lấy được Metrics lỗi 5xx, RAM và tự động sinh Ingress, Cluster của bạn bắt buộc phải cài đặt **Kube-Prometheus-Stack** và **AWS Load Balancer Controller**.

### 1. Cài đặt Kube-Prometheus-Stack (Lấy số liệu 5xx, RAM)
Thêm repo Helm của prometheus-community
helm repo add prometheus-community [https://prometheus-community.github.io/helm-charts](https://prometheus-community.github.io/helm-charts)
helm repo update
Tạo namespace và cài đặt stack giám sát
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
Yêu Cầu Phân Quyền cho Agent
1. Cài đặt các thư viện Python

pip install python-telegram-bot kubernetes openai requests
2. Cấu hình Biến Môi Trường (Environment Variables)
Bash
export OPENROUTER_API_KEY="your-openrouter-api-key-here"
kubectl apply -f agent-rbac.yaml
