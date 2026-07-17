# Dùng bản 3.12 để tương thích hoàn toàn với các lib mới nhất
FROM python:3.12-slim

WORKDIR /app

# Copy file requirements trước để tận dụng Docker Cache
COPY requirements.txt .

# Cài đặt toàn bộ thư viện từ file
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy source code vào sau
COPY agent.py .

# Chạy agent
CMD ["python", "agent.py"]
