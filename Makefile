SHELL := cmd.exe
.SHELLFLAGS := /c

# Main environment configuration
-include .env

# Optional variables with secrets
-include .secrets

# Read installed services from .services file
INSTALLED_SVCS := $(shell type .services 2>nul | find /v "#")

# Targets to manage services
.PHONY: up down check-missing-services help

# Start all installed services
up: check-docker check-missing-services
	@echo Starting all installed services...
	@echo.
	@for %%s in ($(INSTALLED_SVCS)) do @(
		if "%%s"=="mock-server" (
			echo [STARTING] %%s && (
				if exist "services\%%s\docker-compose.yml" (
					docker-compose -f "services/%%s/docker-compose.yml" up -d
				) else (
					echo [ERROR] mock-server is required but not found! && 
					exit /b 1
				)
			)
		) else if exist "services\%%s\docker-compose.yml" (
			echo [STARTING] %%s && 
			docker-compose -f "services/%%s/docker-compose.yml" up -d
		) else (
			echo [SKIPPING] %%s - service not found
		)
		echo.
	)
	@echo All available services started successfully!
	@echo.

check-docker:
	@where docker-compose >nul 2>&1 || echo ERROR: docker-compose not found in PATH & echo Install Docker Desktop from https://www.docker.com/products/docker-desktop & exit /b 1

check-missing-services:
	@echo Checking for missing services...
	@setlocal enabledelayedexpansion
	@set "MISSING="
	@for %%s in ($(INSTALLED_SVCS)) do @(
		if not "%%s"=="mock-server" if not exist "services\%%s\docker-compose.yml" (
			set "MISSING=!MISSING! %%s"
		)
	)
	@if not "!MISSING!"=="" (
		echo.
		echo Warning: Missing local services detected:
		for %%s in ($(INSTALLED_SVCS)) do @(
			if not "%%s"=="mock-server" if not exist "services\%%s\docker-compose.yml" (
				echo   - %%s (not found locally)
			)
		)
		echo.
		echo You can use mock-server to simulate these services during development.
		echo Run 'make up/mock-server' to start the mock server.
		echo.
		timeout /t 3 > nul
	)
	@endlocal

# Start mock server with JSON Server
up/mock-server:
	@if not exist "services\mock-server\docker-compose.yml" ( \
		echo [ERROR] mock-server is required but not found! & \
		exit /b 1 \
	)
	@echo Starting JSON Server for mock APIs...
	@echo.
	@docker-compose -f services/mock-server/docker-compose.yml up -d
	@timeout /t 5 /nobreak >nul
	@echo Mock server started at http://localhost:3000
	@setlocal enabledelayedexpansion & \
	set "MOCKED_ENDPOINTS=" & \
	for %%s in ($(INSTALLED_SVCS)) do @( \
		if not "%%s"=="mock-server" if not exist "services\%%s\docker-compose.yml" ( \
			set "MOCKED_ENDPOINTS=!MOCKED_ENDPOINTS! %%s" \
		) \
	) & \
	if not "!MOCKED_ENDPOINTS!"=="" ( \
		echo Available mock endpoints: & \
		for %%s in (!MOCKED_ENDPOINTS!) do @echo   - http://localhost:3000/%%s \
	) else ( \
		echo No services configured for mocking \
	) & \
	endlocal
	@echo.

# Stop all services
down:
	@echo Stopping all services...
	@echo.
	@for %%s in ($(INSTALLED_SVCS)) do @( \
		if exist "services\%%s\docker-compose.yml" ( \
			echo [STOPPING] %%s ^&^& \
			docker-compose -f services/%%s/docker-compose.yml down \
		) else if "%%s"=="mock-server" ( \
			echo [ERROR] mock-server is required but not found! ^&^& \
			exit /b 1 \
		) else ( \
			echo [SKIPPING] %%s - service not found \
		) \
		echo. \
	)
	@echo All services stopped!
	@echo.

# Stop specific service
down/%:
	@if not exist ".services" ( \
		echo .services file not found & \
		exit /b 1 \
	)
	@findstr /r /c:"^$*$$" .services >nul || ( \
		echo Service $* is not listed in .services file & \
		exit /b 1 \
	)
	@if "$*"=="mock-server" ( \
		if exist "services\mock-server\docker-compose.yml" ( \
			echo Stopping mock-server... & \
			docker-compose -f services/mock-server/docker-compose.yml down \
		) else ( \
			echo [ERROR] mock-server is required but not found! & \
			exit /b 1 \
		) \
	) else if exist "services\$*\docker-compose.yml" ( \
		echo Stopping service $*... & \
		docker-compose -f services/$*/docker-compose.yml down \
	) else ( \
		echo Service $* not found - nothing to stop \
	)

# Help target with full command list
help:
	@echo.
	@echo ===================== Development Environment Control =====================
	@echo.
	@echo Available commands:
	@echo.
	@echo   make up                - Start all installed services
	@echo   make up/mock-server    - Start mock server for missing services
	@echo   make up/service-name   - Start specific service
	@echo   make down              - Stop all services
	@echo   make down/service-name - Stop specific service
	@echo   make help              - Show this help message
	@echo.
	@echo Service management:
	@echo   - Services are defined in .services file
	@echo   - Each service should have its own subfolder in services/
	@echo   - Missing services can be simulated using mock-server
	@echo.
	@echo Current services in .services:
	@for %%s in ($(INSTALLED_SVCS)) do @echo   - %%s
	@echo.
	@echo ========================================================================
	@echo.