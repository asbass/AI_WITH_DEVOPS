FROM python:3.10-slim

WORKDIR /app

# Cài đặt git nếu thư viện cần pull từ repo
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Kiểm tra xem code có chạy được không ngay khi build


CMD ["python", "agent.py"]
