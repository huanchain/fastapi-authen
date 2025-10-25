# FastAPI Authentication API Makefile

.PHONY: help install dev test format lint clean setup migrate db-create db-reset prod

# Default target
help: ## Show this help message
	@echo "FastAPI Authentication API - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development commands
install: ## Install dependencies
	./start.sh setup

dev: ## Start development server
	./start.sh dev

test: ## Run tests
	./start.sh test

format: ## Format code with black and isort
	./start.sh format

lint: ## Lint code with flake8
	./start.sh lint

# Database commands
migrate: ## Run database migrations
	./start.sh migrate

db-create: ## Create database
	./start.sh db-create

db-reset: ## Reset database (drop and recreate)
	./start.sh db-reset

# Production commands
prod: ## Start production server
	./start.sh prod

prod-gunicorn: ## Start production server with Gunicorn
	./start.sh prod-gunicorn

# Utility commands
clean: ## Clean up project files
	./start.sh clean

setup: ## Setup project (install deps, create venv, etc.)
	./start.sh setup

# Quick commands
run: dev ## Alias for dev command
start: dev ## Alias for dev command
