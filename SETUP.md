# Hướng dẫn Setup FastAPI Authentication API

## 🚀 Bắt đầu nhanh

### 1. Chạy script setup tự động
```bash
./start.sh setup
```

### 2. Hoặc chạy từng bước thủ công

#### Bước 1: Cài đặt dependencies
```bash
./start.sh install
```

#### Bước 2: Tạo file cấu hình
```bash
cp env.example .env
# Chỉnh sửa file .env với cấu hình của bạn
```

#### Bước 3: Chạy database
```bash
# Sử dụng Docker (khuyến nghị)
docker-compose up -d postgres redis

# Hoặc cài đặt PostgreSQL và Redis trực tiếp
```

#### Bước 4: Chạy migrations
```bash
./start.sh migrate
```

#### Bước 5: Khởi động server
```bash
./start.sh dev
```

## 📋 Các lệnh có sẵn

### Development Commands
```bash
./start.sh dev          # Khởi động development server
./start.sh test         # Chạy tests
./start.sh format       # Format code với black và isort
./start.sh lint         # Lint code với flake8
./start.sh migrate      # Chạy database migrations
./start.sh setup        # Setup toàn bộ project
```

### Production Commands
```bash
./start.sh prod         # Khởi động production server
./start.sh prod-gunicorn # Khởi động với Gunicorn
```

### Database Commands
```bash
./start.sh db-create    # Tạo database
./start.sh db-migrate   # Chạy migrations
./start.sh db-reset     # Reset database (xóa và tạo lại)
```

### Utility Commands
```bash
./start.sh clean        # Dọn dẹp project
./start.sh help         # Hiển thị help
```

## 🐳 Sử dụng Docker

### Khởi động database và Redis
```bash
docker-compose up -d
```

### Dừng services
```bash
docker-compose down
```

### Xem logs
```bash
docker-compose logs -f
```

## 🔧 Cấu hình

### File .env
Sao chép `env.example` thành `.env` và cấu hình:

```env
# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/fastapi_auth

# JWT
SECRET_KEY=your-secret-key-here

# Email (tùy chọn)
SMTP_HOST=smtp.gmail.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

## 🧪 Testing

### Chạy tất cả tests
```bash
./start.sh test
```

### Chạy tests với coverage
```bash
pytest --cov=app test_api.py
```

## 📝 Code Quality

### Format code
```bash
./start.sh format
```

### Lint code
```bash
./start.sh lint
```

### Setup pre-commit hooks
```bash
pre-commit install
```

## 🚀 Production Deployment

### 1. Cấu hình production
- Cập nhật file `.env` với cấu hình production
- Đặt `DEBUG=false`
- Sử dụng secret key mạnh
- Cấu hình database production

### 2. Chạy migrations
```bash
./start.sh migrate
```

### 3. Khởi động với Gunicorn
```bash
./start.sh prod-gunicorn
```

## 🔍 Troubleshooting

### Lỗi database connection
```bash
# Kiểm tra PostgreSQL có chạy không
pg_isready -h localhost -p 5432

# Khởi động PostgreSQL
brew services start postgresql  # macOS
sudo systemctl start postgresql  # Linux
```

### Lỗi Redis connection
```bash
# Kiểm tra Redis có chạy không
redis-cli ping

# Khởi động Redis
brew services start redis  # macOS
sudo systemctl start redis  # Linux
```

### Lỗi permissions
```bash
# Cấp quyền execute cho script
chmod +x start.sh
```

### Lỗi dependencies
```bash
# Cài đặt lại dependencies
./start.sh clean
./start.sh setup
```

## 📚 API Documentation

Sau khi khởi động server, truy cập:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

## 🎯 Next Steps

1. Cấu hình email service cho password reset
2. Setup OAuth2 providers (Google, GitHub)
3. Cấu hình monitoring và logging
4. Setup CI/CD pipeline
5. Deploy lên production server
