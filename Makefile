SHELL := /bin/bash

-include .env
-include .secrets

SERVICES_DIR := services
SERVICES := $(shell find $(SERVICES_DIR) -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

.PHONY: up down up/% down/% up/mock-server help

# Start all services (each service's own docker-compose.yml)
up:
	@echo "Starting all available services..."
	@for svc in $(SERVICES); do \
		FILE="$(SERVICES_DIR)/$$svc/docker-compose.yml"; \
		if [ -f "$$FILE" ]; then \
			echo "[STARTING] $$svc"; \
			docker-compose -f "$$FILE" up -d; \
		else \
			echo "[SKIPPING] $$svc - no docker-compose.yml found"; \
		fi; \
		echo ""; \
	done
	@echo "All services started (where possible)."

# Stop all services
down:
	@echo "Stopping all services..."
	@for svc in $(SERVICES); do \
		FILE="$(SERVICES_DIR)/$$svc/docker-compose.yml"; \
		if [ -f "$$FILE" ]; then \
			echo "[STOPPING] $$svc"; \
			docker-compose -f "$$FILE" down; \
		else \
			echo "[SKIPPING] $$svc - no docker-compose.yml found"; \
		fi; \
		echo ""; \
	done
	@echo "All services stopped (where possible)."

# Start mock server (shortcut)
up/mock-server:
	@FILE="$(SERVICES_DIR)/mock-server/docker-compose.yml"; \
	if [ ! -f "$$FILE" ]; then \
		echo "[ERROR] mock-server not found!"; \
		exit 1; \
	fi; \
	echo "Starting mock-server..."; \
	docker-compose -f "$$FILE" up -d; \
	sleep 2; \
	echo "Mock server running at http://localhost:3000"

# Stop individual service: make down/service-name
down/%:
	@FILE="$(SERVICES_DIR)/$*/docker-compose.yml"; \
	if [ -f "$$FILE" ]; then \
		echo "Stopping service '$*'..."; \
		docker-compose -f "$$FILE" down; \
	else \
		echo "Service '$*' not found or no docker-compose.yml present."; \
	fi

# Help
help:
	@echo ""
	@echo "==================== Service Management ===================="
	@echo ""
	@echo "Available commands:"
	@echo ""
	@echo "  make up                 - Start all services in ./services/"
	@echo "  make down               - Stop all services"
	@echo "  make up/mock-server     - Start mock server"
	@echo "  make down/service-name  - Stop specific service"
	@echo "  make help               - Show this help message"
	@echo ""
	@echo "Detected services:"
	@for svc in $(SERVICES); do echo "  - $$svc"; done
	@echo ""
	@echo "============================================================"
