@echo off
REM ===========================================
REM Quick Start - Run a simple test
REM ===========================================

echo ============================================
echo ZGC Spring Boot Test - Quick Start
echo ============================================
echo.

REM Check Java
java -version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Java not found! Please install Java 21+
    pause
    exit /b 1
)

REM Check Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker not found! Please install Docker Desktop
    pause
    exit /b 1
)

echo Step 1: Starting PostgreSQL...
docker compose up -d
if errorlevel 1 (
    echo ERROR: Failed to start PostgreSQL
    pause
    exit /b 1
)
echo PostgreSQL started!
echo.

REM Wait a bit for Postgres to be ready
echo Waiting for PostgreSQL to initialize...
timeout /t 5 /nobreak >nul

echo Step 2: Building application...
call mvn clean package -DskipTests -Dquick
if errorlevel 1 (
    echo ERROR: Build failed!
    pause
    exit /b 1
)
echo Build complete!
echo.

echo Step 3: Running quick benchmark (60 seconds with G1GC)...
echo.
call bench.bat --duration 60 --qps 500 --gc G1

echo.
echo ============================================
echo Quick test complete!
echo ============================================
echo.
echo Next steps:
echo   1. Run full comparison: run-comparison.bat
echo   2. Test with ZGC: bench.bat --gc ZGC
echo   3. Check results in 'results' folder
echo   4. Open .jfr files in JDK Mission Control
echo.
pause
