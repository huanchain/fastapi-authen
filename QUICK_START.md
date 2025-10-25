# 🚀 Quick Start Guide

## Bắt đầu nhanh

### 1. Chạy setup tự động
```bash
./start.sh setup
```

### 2. Khởi động server
```bash
./start.sh dev
```

### 3. Mở Swagger UI
Truy cập: http://localhost:8000/docs

## 📋 Các lệnh chính

```bash
# Development
./start.sh dev          # Khởi động development server
./start.sh test         # Chạy tests
./start.sh format       # Format code
./start.sh lint         # Lint code

# Database
./start.sh db-create    # Tạo database
./start.sh db-migrate   # Chạy migrations
./start.sh db-reset     # Reset database

# Utilities
./start.sh guide        # Hiển thị hướng dẫn chi tiết
./start.sh help         # Hiển thị tất cả lệnh
./start.sh clean        # Dọn dẹp project
```

## 🎯 Test API nhanh

### 1. Test health endpoint
```bash
curl http://localhost:8000/health
```

### 2. Đăng ký user mới
```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","username":"testuser","password":"testpass123"}'
```

### 3. Đăng nhập
```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass123"}'
```

### 4. Lấy thông tin user (thay YOUR_TOKEN)
```bash
curl -X GET http://localhost:8000/api/v1/users/me \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## 📚 Tài liệu API

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

## 🔧 Cấu hình

1. Sao chép file cấu hình:
```bash
cp env.example .env
```

2. Chỉnh sửa file `.env` với cấu hình của bạn

## 🐳 Sử dụng Docker

```bash
# Khởi động database và Redis
docker-compose up -d

# Dừng services
docker-compose down
```

## 📖 Hướng dẫn chi tiết

Chạy lệnh sau để xem hướng dẫn đầy đủ:
```bash
./start.sh guide
```
