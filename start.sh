#!/bin/bash

# FastAPI Authentication API Startup Script
# This script sets up and starts the FastAPI authentication API with all necessary tools

# Note: set -e is disabled to allow retry functions to work properly
# Individual commands will handle their own error checking

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=2

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_retry() {
    echo -e "${YELLOW}[RETRY]${NC} $1"
}

# Retry function with exponential backoff
retry_with_backoff() {
    local max_attempts=$1
    local delay=$2
    local command="${@:3}"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                print_retry "Attempt $attempt failed. Retrying in ${delay}s... (${attempt}/${max_attempts})"
                sleep $delay
                delay=$((delay * 2))  # Exponential backoff
                attempt=$((attempt + 1))
            else
                print_error "All $max_attempts attempts failed for command: $command"
                return 1
            fi
        fi
    done
}

# Retry function with fixed delay
retry_fixed() {
    local max_attempts=$1
    local delay=$2
    local command="${@:3}"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                print_retry "Attempt $attempt failed. Retrying in ${delay}s... (${attempt}/${max_attempts})"
                sleep $delay
                attempt=$((attempt + 1))
            else
                print_error "All $max_attempts attempts failed for command: $command"
                return 1
            fi
        fi
    done
}

# Check if required system tools are installed
check_system_tools() {
    print_status "Checking system tools..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install Python 3.8 or higher."
        print_error "Install with: brew install python3 (macOS) or apt install python3 (Ubuntu)"
        exit 1
    fi
    
    python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    # Check Python version without bc dependency
    major=$(echo $python_version | cut -d'.' -f1)
    minor=$(echo $python_version | cut -d'.' -f2)
    if [ "$major" -lt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -lt 8 ]); then
        print_error "Python 3.8 or higher is required. Current version: $python_version"
        exit 1
    fi
    print_success "Python $(python3 --version) is installed"
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 is not installed. Please install pip."
        exit 1
    fi
    print_success "pip3 is installed"
    
    # Check PostgreSQL
    if ! command -v psql &> /dev/null; then
        print_warning "PostgreSQL client (psql) not found."
        print_warning "Install with: brew install postgresql (macOS) or apt install postgresql-client (Ubuntu)"
    else
        print_success "PostgreSQL client is installed"
    fi
    
    # Check Redis
    if ! command -v redis-cli &> /dev/null; then
        print_warning "Redis client not found."
        print_warning "Install with: brew install redis (macOS) or apt install redis-tools (Ubuntu)"
    else
        print_success "Redis client is installed"
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        print_warning "Git not found. Install with: brew install git (macOS) or apt install git (Ubuntu)"
    else
        print_success "Git is installed"
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        print_warning "curl not found. Install with: brew install curl (macOS) or apt install curl (Ubuntu)"
    else
        print_success "curl is installed"
    fi
}

# Check if virtual environment exists
check_venv() {
    if [ ! -d "venv" ]; then
        print_warning "Virtual environment not found. Creating one..."
        if python3 -m venv venv; then
            print_success "Virtual environment created"
        else
            print_error "Failed to create virtual environment"
            return 1
        fi
    else
        print_success "Virtual environment found"
    fi
}

# Activate virtual environment
activate_venv() {
    print_status "Activating virtual environment..."
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
        print_success "Virtual environment activated"
    else
        print_error "Virtual environment activation script not found"
        return 1
    fi
}

# Install dependencies
install_dependencies() {
    print_status "Installing Python dependencies..."
    
    # Retry pip upgrade
    if ! retry_fixed $MAX_RETRIES $RETRY_DELAY "pip install --upgrade pip"; then
        print_error "Failed to upgrade pip after $MAX_RETRIES attempts"
        return 1
    fi
    
    # Retry requirements installation
    if ! retry_fixed $MAX_RETRIES $RETRY_DELAY "pip install -r requirements.txt"; then
        print_error "Failed to install requirements after $MAX_RETRIES attempts"
        return 1
    fi
    
    # Install development tools with retry
    print_status "Installing development tools..."
    if ! retry_fixed $MAX_RETRIES $RETRY_DELAY "pip install black isort flake8 mypy pre-commit"; then
        print_warning "Some development tools failed to install, but continuing..."
    fi
    
    print_success "Dependencies installed"
}

# Install pre-commit hooks
setup_pre_commit() {
    print_status "Setting up pre-commit hooks..."
    if [ -f ".pre-commit-config.yaml" ]; then
        retry_fixed $MAX_RETRIES $RETRY_DELAY "pre-commit install"
        print_success "Pre-commit hooks installed"
    else
        print_warning "No .pre-commit-config.yaml found, skipping pre-commit setup"
    fi
}

# Check if .env file exists
check_env() {
    if [ ! -f ".env" ]; then
        print_warning ".env file not found. Creating from env.example..."
        if [ -f "env.example" ]; then
            cp env.example .env
            print_warning "Please edit .env file with your configuration before running again"
            print_warning "Required: DATABASE_URL, SECRET_KEY, and other settings"
            exit 1
        else
            print_error ".env file not found and no env.example to copy from"
            print_error "Please create a .env file with your configuration"
            exit 1
        fi
    else
        print_success ".env file found"
    fi
}

# Check if database is accessible
check_database() {
    print_status "Checking database connection..."
    # Extract database info from DATABASE_URL
    if grep -q "DATABASE_URL=" .env; then
        db_url=$(grep "DATABASE_URL=" .env | cut -d'=' -f2- | tr -d ' ')
        if [[ $db_url == postgresql* ]]; then
            # Extract host, port, database name from postgresql URL with error handling
            db_host=$(echo $db_url | sed 's/.*@\([^:]*\):.*/\1/' 2>/dev/null || echo "localhost")
            db_port=$(echo $db_url | sed 's/.*:\([0-9]*\)\/.*/\1/' 2>/dev/null || echo "5432")
            db_name=$(echo $db_url | sed 's/.*\/\([^?]*\).*/\1/' 2>/dev/null || echo "fastapi_auth")
            
            # Validate extracted values
            if [[ -z "$db_host" || "$db_host" == "$db_url" ]]; then
                print_warning "Could not parse database host from DATABASE_URL"
                return 0
            fi
            
            # Check if PostgreSQL is running with retry
            if command -v pg_isready &> /dev/null; then
                if retry_fixed $MAX_RETRIES $RETRY_DELAY "pg_isready -h $db_host -p $db_port"; then
                    print_success "Database connection successful"
                else
                    print_warning "PostgreSQL is not running or not accessible after $MAX_RETRIES attempts"
                    print_warning "Please start PostgreSQL and ensure the database exists"
                    print_warning "You can create the database with: createdb $db_name"
                    print_warning "Or start PostgreSQL with: brew services start postgresql (macOS)"
                fi
            else
                print_warning "pg_isready not found, cannot check database connection"
            fi
        fi
    else
        print_warning "DATABASE_URL not found in .env file"
    fi
}

# Create database if it doesn't exist
create_database() {
    print_status "Checking if database exists..."
    if grep -q "DATABASE_URL=" .env; then
        db_url=$(grep "DATABASE_URL=" .env | cut -d'=' -f2- | tr -d ' ')
        if [[ $db_url == postgresql* ]]; then
            # Extract database info with error handling
            db_name=$(echo $db_url | sed 's/.*\/\([^?]*\).*/\1/' 2>/dev/null || echo "fastapi_auth")
            db_user=$(echo $db_url | sed 's/postgresql:\/\/\([^:]*\):.*/\1/' 2>/dev/null || echo "postgres")
            db_host=$(echo $db_url | sed 's/.*@\([^:]*\):.*/\1/' 2>/dev/null || echo "localhost")
            db_port=$(echo $db_url | sed 's/.*:\([0-9]*\)\/.*/\1/' 2>/dev/null || echo "5432")
            
            # Validate extracted values
            if [[ -z "$db_name" || "$db_name" == "$db_url" ]]; then
                print_warning "Could not parse database name from DATABASE_URL"
                return 0
            fi
            
            # Check if database exists
            if command -v psql &> /dev/null; then
                # Test connection first
                if psql -h $db_host -p $db_port -U $db_user -c '\q' 2>/dev/null; then
                    if ! psql -h $db_host -p $db_port -U $db_user -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw $db_name; then
                        print_warning "Database '$db_name' does not exist. Creating..."
                        if createdb -h $db_host -p $db_port -U $db_user $db_name 2>/dev/null; then
                            print_success "Database '$db_name' created successfully"
                        else
                            print_warning "Could not create database '$db_name'. Please create it manually."
                        fi
                    else
                        print_success "Database '$db_name' already exists"
                    fi
                else
                    print_warning "Cannot connect to PostgreSQL server. Please ensure it's running."
                fi
            else
                print_warning "psql not found. Please install PostgreSQL client."
                
            fi
        fi
    fi
}

# Run database migrations
run_migrations() {
    print_status "Running database migrations..."
    if command -v alembic &> /dev/null; then
        if alembic upgrade head; then
            print_success "Database migrations completed"
        else
            print_warning "Database migrations failed. Please check your database connection and configuration."
            print_warning "You can try running migrations manually with: alembic upgrade head"
        fi
    else
        print_warning "Alembic not found. Please install dependencies first"
    fi
}

# Run tests
run_tests() {
    print_status "Running tests..."
    if command -v pytest &> /dev/null; then
        pytest test_api.py -v
        print_success "Tests completed"
    else
        print_warning "pytest not found. Please install dependencies first"
    fi
}

# Format code
format_code() {
    print_status "Formatting code..."
    if command -v black &> /dev/null; then
        black .
        print_success "Code formatted with black"
    else
        print_warning "black not found. Please install dependencies first"
    fi
    
    if command -v isort &> /dev/null; then
        isort .
        print_success "Imports sorted with isort"
    else
        print_warning "isort not found. Please install dependencies first"
    fi
}

# Lint code
lint_code() {
    print_status "Linting code..."
    if command -v flake8 &> /dev/null; then
        flake8 . --max-line-length=88 --extend-ignore=E203,W503
        print_success "Code linted with flake8"
    else
        print_warning "flake8 not found. Please install dependencies first"
    fi
}

# Check if Redis is running (optional)
check_redis() {
    if grep -q "REDIS_URL=" .env; then
        redis_url=$(grep "REDIS_URL=" .env | cut -d'=' -f2-)
        if [[ $redis_url == redis* ]]; then
            redis_host=$(echo $redis_url | sed 's/redis:\/\/\([^:]*\):.*/\1/')
            redis_port=$(echo $redis_url | sed 's/.*:\([0-9]*\).*/\1/')
            
            if command -v redis-cli &> /dev/null; then
                if redis-cli -h $redis_host -p $redis_port ping &> /dev/null; then
                    print_success "Redis connection successful"
                else
                    print_warning "Redis is not running or not accessible"
                    print_warning "Please start Redis if you plan to use it"
                fi
            fi
        fi
    fi
}

# Check if server is already running
check_server_running() {
    if curl -s http://localhost:8000/health >/dev/null 2>&1; then
        print_warning "Server is already running on http://localhost:8000"
        return 1
    fi
    return 0
}

# Stop any running server
stop_server() {
    print_status "Checking for running server..."
    
    # Find and kill any existing server processes
    local server_pids=$(ps aux | grep -E "python.*run.py|uvicorn.*app.main" | grep -v grep | awk '{print $2}')
    
    if [ -n "$server_pids" ]; then
        print_warning "Found running server processes: $server_pids"
        print_status "Stopping existing server..."
        echo "$server_pids" | xargs kill -9 2>/dev/null || true
        sleep 2
        print_success "Server stopped"
    else
        print_success "No running server found"
    fi
}

# Start the FastAPI server
start_server() {
    print_status "Starting FastAPI server..."
    
    # Stop any existing server first
    stop_server
    
    echo ""
    echo -e "${CYAN}🚀 FastAPI Authentication API is starting...${NC}"
    echo ""
    echo -e "${GREEN}📋 Available Endpoints:${NC}"
    echo -e "  🌐 Main API:     ${BLUE}http://localhost:8000${NC}"
    echo -e "  📚 Swagger UI:   ${BLUE}http://localhost:8000/docs${NC}"
    echo -e "  📖 ReDoc:        ${BLUE}http://localhost:8000/redoc${NC}"
    echo -e "  ❤️  Health Check: ${BLUE}http://localhost:8000/health${NC}"
    echo ""
    echo -e "${GREEN}🔐 Authentication Endpoints:${NC}"
    echo -e "  📝 Register:     ${BLUE}POST /api/v1/auth/register${NC}"
    echo -e "  🔑 Login:        ${BLUE}POST /api/v1/auth/login${NC}"
    echo -e "  🚪 Logout:       ${BLUE}POST /api/v1/auth/logout${NC}"
    echo -e "  🔒 Change Pass:  ${BLUE}POST /api/v1/auth/change-password${NC}"
    echo ""
    echo -e "${GREEN}👤 User Management:${NC}"
    echo -e "  👤 Profile:      ${BLUE}GET /api/v1/users/me${NC}"
    echo -e "  ✏️  Update:       ${BLUE}PUT /api/v1/users/me${NC}"
    echo -e "  🔑 API Keys:     ${BLUE}GET /api/v1/users/api-keys${NC}"
    echo ""
    echo -e "${GREEN}🔐 MFA (Multi-Factor Auth):${NC}"
    echo -e "  ⚙️  Setup:        ${BLUE}POST /api/v1/mfa/setup${NC}"
    echo -e "  ✅ Verify:       ${BLUE}POST /api/v1/mfa/verify${NC}"
    echo -e "  📊 Status:       ${BLUE}GET /api/v1/mfa/status${NC}"
    echo ""
    echo -e "${GREEN}🌐 OAuth2 Integration:${NC}"
    echo -e "  🔵 Google:       ${BLUE}GET /api/v1/oauth/google${NC}"
    echo -e "  🐙 GitHub:       ${BLUE}GET /api/v1/oauth/github${NC}"
    echo ""
    echo -e "${YELLOW}💡 Quick Test Examples:${NC}"
    echo -e "  ${CYAN}# Test health endpoint${NC}"
    echo -e "  ${PURPLE}curl http://localhost:8000/health${NC}"
    echo ""
    echo -e "  ${CYAN}# Register a new user${NC}"
    echo -e "  ${PURPLE}curl -X POST http://localhost:8000/api/v1/auth/register \\${NC}"
    echo -e "  ${PURPLE}  -H \"Content-Type: application/json\" \\${NC}"
    echo -e "  ${PURPLE}  -d '{\"email\":\"test@example.com\",\"username\":\"testuser\",\"password\":\"testpass123\"}'${NC}"
    echo ""
    echo -e "  ${CYAN}# Login${NC}"
    echo -e "  ${PURPLE}curl -X POST http://localhost:8000/api/v1/auth/login \\${NC}"
    echo -e "  ${PURPLE}  -H \"Content-Type: application/json\" \\${NC}"
    echo -e "  ${PURPLE}  -d '{\"username\":\"testuser\",\"password\":\"testpass123\"}'${NC}"
    echo ""
    echo -e "  ${CYAN}# Get user profile (with token)${NC}"
    echo -e "  ${PURPLE}curl -X GET http://localhost:8000/api/v1/users/me \\${NC}"
    echo -e "  ${PURPLE}  -H \"Authorization: Bearer YOUR_ACCESS_TOKEN\"${NC}"
    echo ""
    echo -e "${GREEN}🎯 Next Steps:${NC}"
    echo -e "  1. Open ${BLUE}http://localhost:8000/docs${NC} in your browser"
    echo -e "  2. Try the interactive API documentation"
    echo -e "  3. Test the authentication endpoints"
    echo -e "  4. Set up MFA for enhanced security"
    echo -e "  5. Configure OAuth2 providers"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
    echo ""
    
    # Start the server
    python run.py
}

# Show detailed API guide
show_api_guide() {
    echo -e "${CYAN}🚀 FastAPI Authentication API - Complete Guide${NC}"
    echo "=================================================="
    echo ""
    echo -e "${GREEN}📚 API Documentation:${NC}"
    echo -e "  🌐 Swagger UI:   ${BLUE}http://localhost:8000/docs${NC} (Interactive API docs)"
    echo -e "  📖 ReDoc:        ${BLUE}http://localhost:8000/redoc${NC} (Alternative docs)"
    echo -e "  ❤️  Health Check: ${BLUE}http://localhost:8000/health${NC} (Server status)"
    echo ""
    echo -e "${GREEN}🔐 Authentication Flow:${NC}"
    echo -e "  1. ${YELLOW}Register${NC} a new user account"
    echo -e "  2. ${YELLOW}Login${NC} to get access token"
    echo -e "  3. Use token in ${YELLOW}Authorization header${NC} for protected endpoints"
    echo -e "  4. ${YELLOW}Setup MFA${NC} for enhanced security (optional)"
    echo ""
    echo -e "${GREEN}📝 Step-by-Step Testing:${NC}"
    echo ""
    echo -e "${CYAN}Step 1: Test Health Endpoint${NC}"
    echo -e "  ${PURPLE}curl http://localhost:8000/health${NC}"
    echo -e "  ${GREEN}Expected:{\"status\":\"healthy\"}${NC}"
    echo ""
    echo -e "${CYAN}Step 2: Register New User${NC}"
    echo -e "  ${PURPLE}curl -X POST http://localhost:8000/api/v1/auth/register \\${NC}"
    echo -e "  ${PURPLE}    -H \"Content-Type: application/json\" \\${NC}"
    echo -e "  ${PURPLE}    -d '{\"email\":\"test@example.com\",\"username\":\"testuser\",\"password\":\"testpass123\"}'${NC}"
    echo -e "  ${GREEN}Expected:{\"message\":\"User created successfully\",\"user_id\":1}${NC}"
    echo ""
    echo -e "${CYAN}Step 3: Login${NC}"
    echo -e "  ${PURPLE}curl -X POST http://localhost:8000/api/v1/auth/login \\${NC}"
    echo -e "  ${PURPLE}    -H \"Content-Type: application/json\" \\${NC}"
    echo -e "  ${PURPLE}    -d '{\"username\":\"testuser\",\"password\":\"testpass123\"}'${NC}"
    echo -e "  ${GREEN}Expected:{\"access_token\":\"...\",\"refresh_token\":\"...\",\"token_type\":\"bearer\"}${NC}"
    echo ""
    echo -e "${CYAN}Step 4: Get User Profile (Replace YOUR_TOKEN)${NC}"
    echo -e "  ${PURPLE}curl -X GET http://localhost:8000/api/v1/users/me \\${NC}"
    echo -e "  ${PURPLE}    -H \"Authorization: Bearer YOUR_ACCESS_TOKEN\"${NC}"
    echo -e "  ${GREEN}Expected: User profile information${NC}"
    echo ""
    echo -e "${CYAN}Step 5: Setup MFA (Optional)${NC}"
    echo -e "  ${PURPLE}curl -X POST http://localhost:8000/api/v1/mfa/setup \\${NC}"
    echo -e "  ${PURPLE}    -H \"Authorization: Bearer YOUR_ACCESS_TOKEN\"${NC}"
    echo -e "  ${GREEN}Expected: QR code and setup instructions${NC}"
    echo ""
    echo -e "${GREEN}🎯 Using Swagger UI:${NC}"
    echo -e "  1. Open ${BLUE}http://localhost:8000/docs${NC} in your browser"
    echo -e "  2. Click on any endpoint to expand it"
    echo -e "  3. Click ${YELLOW}'Try it out'${NC} button"
    echo -e "  4. Fill in the required parameters"
    echo -e "  5. Click ${YELLOW}'Execute'${NC} to test the endpoint"
    echo -e "  6. View the response and status code"
    echo ""
    echo -e "${GREEN}🔑 Authentication in Swagger:${NC}"
    echo -e "  1. First, call ${YELLOW}/api/v1/auth/login${NC} to get a token"
    echo -e "  2. Copy the ${YELLOW}access_token${NC} from the response"
    echo -e "  3. Click the ${YELLOW}'Authorize'${NC} button (🔒) at the top"
    echo -e "  4. Enter: ${YELLOW}Bearer YOUR_ACCESS_TOKEN${NC}"
    echo -e "  5. Click ${YELLOW}'Authorize'${NC} and then ${YELLOW}'Close'${NC}"
    echo -e "  6. Now you can test protected endpoints!"
    echo ""
    echo -e "${GREEN}📊 Available Endpoints Summary:${NC}"
    echo -e "  ${YELLOW}Authentication:${NC}"
    echo -e "    POST /api/v1/auth/register          - Create new user"
    echo -e "    POST /api/v1/auth/login             - Login user"
    echo -e "    POST /api/v1/auth/logout            - Logout user"
    echo -e "    POST /api/v1/auth/change-password   - Change password"
    echo -e "    POST /api/v1/auth/reset-password    - Request password reset"
    echo ""
    echo -e "  ${YELLOW}User Management:${NC}"
    echo -e "    GET  /api/v1/users/me               - Get user profile"
    echo -e "    PUT  /api/v1/users/me               - Update user profile"
    echo -e "    POST /api/v1/users/api-keys         - Create API key"
    echo -e "    GET  /api/v1/users/api-keys         - List API keys"
    echo -e "    DELETE /api/v1/users/api-keys/{id}  - Revoke API key"
    echo ""
    echo -e "  ${YELLOW}MFA (Multi-Factor Auth):${NC}"
    echo -e "    POST /api/v1/mfa/setup              - Setup MFA"
    echo -e "    POST /api/v1/mfa/verify             - Verify MFA code"
    echo -e "    POST /api/v1/mfa/disable            - Disable MFA"
    echo -e "    GET  /api/v1/mfa/status             - Get MFA status"
    echo ""
    echo -e "  ${YELLOW}OAuth2:${NC}"
    echo -e "    GET  /api/v1/oauth/google           - Google OAuth login"
    echo -e "    GET  /api/v1/oauth/github           - GitHub OAuth login"
    echo ""
    echo -e "${GREEN}🛠️ Development Tips:${NC}"
    echo -e "  • Use ${BLUE}./start.sh test${NC} to run all tests"
    echo -e "  • Use ${BLUE}./start.sh format${NC} to format code"
    echo -e "  • Use ${BLUE}./start.sh lint${NC} to check code quality"
    echo -e "  • Check logs in terminal for debugging"
    echo -e "  • Use browser developer tools for network inspection"
    echo ""
}

# Show help information
show_help() {
    echo -e "${CYAN}FastAPI Authentication API - Available Commands:${NC}"
    echo ""
    echo -e "${GREEN}Development Commands:${NC}"
    echo "  ./start.sh dev          - Start development server with all checks"
    echo "  ./start.sh test         - Run tests only"
    echo "  ./start.sh format       - Format code with black and isort"
    echo "  ./start.sh lint         - Lint code with flake8"
    echo "  ./start.sh migrate      - Run database migrations only"
    echo "  ./start.sh setup        - Setup project (install deps, create venv, etc.)"
    echo ""
    echo -e "${GREEN}Production Commands:${NC}"
    echo "  ./start.sh prod         - Start production server"
    echo "  ./start.sh prod-gunicorn - Start with Gunicorn (production)"
    echo ""
    echo -e "${GREEN}Database Commands:${NC}"
    echo "  ./start.sh db-create    - Create database"
    echo "  ./start.sh db-migrate   - Run migrations"
    echo "  ./start.sh db-reset     - Reset database (drop and recreate)"
    echo ""
    echo -e "${GREEN}Utility Commands:${NC}"
    echo "  ./start.sh stop         - Stop running server"
    echo "  ./start.sh clean        - Clean up (remove venv, __pycache__, etc.)"
    echo "  ./start.sh guide        - Show detailed API usage guide"
    echo "  ./start.sh help         - Show this help message"
    echo ""
}

# Clean up project
clean_project() {
    print_status "Cleaning up project..."
    
    # Remove virtual environment
    if [ -d "venv" ]; then
        rm -rf venv
        print_success "Virtual environment removed"
    fi
    
    # Remove Python cache
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete 2>/dev/null || true
    print_success "Python cache files removed"
    
    # Remove test coverage
    rm -rf htmlcov/ .coverage .pytest_cache/ 2>/dev/null || true
    print_success "Test coverage files removed"
    
    print_success "Project cleaned up"
}

# Reset database
reset_database() {
    print_status "Resetting database..."
    if grep -q "DATABASE_URL=" .env; then
        db_url=$(grep "DATABASE_URL=" .env | cut -d'=' -f2- | tr -d ' ')
        if [[ $db_url == postgresql* ]]; then
            # Extract database info with error handling
            db_name=$(echo $db_url | sed 's/.*\/\([^?]*\).*/\1/' 2>/dev/null || echo "fastapi_auth")
            db_user=$(echo $db_url | sed 's/postgresql:\/\/\([^:]*\):.*/\1/' 2>/dev/null || echo "postgres")
            db_host=$(echo $db_url | sed 's/.*@\([^:]*\):.*/\1/' 2>/dev/null || echo "localhost")
            db_port=$(echo $db_url | sed 's/.*:\([0-9]*\)\/.*/\1/' 2>/dev/null || echo "5432")
            
            # Validate extracted values
            if [[ -z "$db_name" || "$db_name" == "$db_url" ]]; then
                print_error "Could not parse database name from DATABASE_URL"
                return 1
            fi
            
            if command -v psql &> /dev/null; then
                # Test connection first
                if psql -h $db_host -p $db_port -U $db_user -c '\q' 2>/dev/null; then
                    print_warning "Dropping database '$db_name'..."
                    if dropdb -h $db_host -p $db_port -U $db_user $db_name --if-exists 2>/dev/null; then
                        print_success "Database dropped"
                    else
                        print_warning "Could not drop database '$db_name'"
                    fi
                    
                    print_status "Creating database '$db_name'..."
                    if createdb -h $db_host -p $db_port -U $db_user $db_name 2>/dev/null; then
                        print_success "Database created"
                        
                        print_status "Running migrations..."
                        if alembic upgrade head 2>/dev/null; then
                            print_success "Database reset completed"
                        else
                            print_warning "Migrations failed. Please run './start.sh migrate' manually"
                        fi
                    else
                        print_error "Could not create database '$db_name'"
                        return 1
                    fi
                else
                    print_error "Cannot connect to PostgreSQL server. Please ensure it's running."
                    return 1
                fi
            else
                print_error "psql not found. Cannot reset database"
                return 1
            fi
        fi
    else
        print_error "DATABASE_URL not found in .env file"
        return 1
    fi
}

# Start production server with Gunicorn
start_production() {
    print_status "Starting production server with Gunicorn..."
    
    # Check if Gunicorn is installed
    if ! command -v gunicorn &> /dev/null; then
        print_error "Gunicorn not found. Installing..."
        pip install gunicorn
    fi
    
    # Start with Gunicorn
    gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
}

# Show quick start guide
show_quick_guide() {
    echo ""
    echo -e "${GREEN}🎉 Server is ready! Quick Start Guide:${NC}"
    echo -e "  📚 Open Swagger UI: ${BLUE}http://localhost:8000/docs${NC}"
    echo -e "  🔍 Test health:     ${BLUE}curl http://localhost:8000/health${NC}"
    echo -e "  📖 Full guide:      ${BLUE}./start.sh guide${NC}"
    echo ""
}

# Main execution
main() {
    echo "🚀 FastAPI Authentication API Startup Script"
    echo "=============================================="
    echo ""
    
    check_system_tools
    check_venv
    activate_venv
    install_dependencies
    setup_pre_commit
    check_env
    create_database
    check_database
    run_migrations
    check_redis
    show_quick_guide
    start_server
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}Shutting down server...${NC}"; exit 0' INT

# Parse command line arguments
case "${1:-dev}" in
    "dev")
        main
        ;;
    "test")
        check_system_tools
        check_venv
        activate_venv
        install_dependencies
        run_tests
        ;;
    "format")
        check_venv
        activate_venv
        format_code
        ;;
    "lint")
        check_venv
        activate_venv
        lint_code
        ;;
    "migrate")
        check_venv
        activate_venv
        check_env
        run_migrations
        ;;
    "setup")
        check_system_tools
        check_venv
        activate_venv
        install_dependencies
        setup_pre_commit
        check_env
        create_database
        run_migrations
        print_success "Project setup completed!"
        ;;
    "prod")
        check_venv
        activate_venv
        check_env
        start_server
        ;;
    "prod-gunicorn")
        check_venv
        activate_venv
        check_env
        start_production
        ;;
    "db-create")
        check_venv
        activate_venv
        check_env
        create_database
        ;;
    "db-migrate")
        check_venv
        activate_venv
        check_env
        run_migrations
        ;;
    "db-reset")
        check_venv
        activate_venv
        check_env
        reset_database
        ;;
    "clean")
        clean_project
        ;;
    "stop")
        check_venv
        activate_venv
        stop_server
        ;;
    "guide")
        show_api_guide
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

