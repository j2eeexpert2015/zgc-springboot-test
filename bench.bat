@echo off
REM ===========================================
REM ZGC Spring Boot Benchmark - Windows Version
REM ===========================================

setlocal enabledelayedexpansion

REM Default values
set DURATION=120
set BENCH=random
set MEM=4096
set QPS=1000
set GC=G1
set WARMUP=30
set APP_PORT=8080

REM Parse arguments
:parse_args
if "%~1"=="" goto :done_parsing
if "%~1"=="--duration" (set DURATION=%~2& shift & shift & goto :parse_args)
if "%~1"=="--bench" (set BENCH=%~2& shift & shift & goto :parse_args)
if "%~1"=="--mem" (set MEM=%~2& shift & shift & goto :parse_args)
if "%~1"=="--qps" (set QPS=%~2& shift & shift & goto :parse_args)
if "%~1"=="--gc" (set GC=%~2& shift & shift & goto :parse_args)
if "%~1"=="--warmup" (set WARMUP=%~2& shift & shift & goto :parse_args)
if "%~1"=="--help" goto :show_help
if "%~1"=="-h" goto :show_help
echo Unknown option: %~1
goto :show_help
:done_parsing

REM Determine GC flags
if "%GC%"=="G1" (
    set GC_FLAGS=-XX:+UseG1GC
    set GC_NAME=G1GC
) else if "%GC%"=="ZGC" (
    set GC_FLAGS=-XX:+UseZGC
    set GC_NAME=ZGC
) else if "%GC%"=="GenZGC" (
    set GC_FLAGS=-XX:+UseZGC -XX:+ZGenerational
    set GC_NAME=GenZGC
) else (
    echo Unknown GC type: %GC%. Use G1, ZGC, or GenZGC
    exit /b 1
)

REM Determine endpoint
if "%BENCH%"=="random" (
    set ENDPOINT=/api/random?count=10
) else if "%BENCH%"=="compute" (
    set ENDPOINT=/api/compute?iterations=1000
) else (
    echo Unknown benchmark type: %BENCH%. Use random or compute
    exit /b 1
)

REM Create timestamp using PowerShell (works on all Windows versions)
for /f "tokens=*" %%i in ('powershell -Command "Get-Date -Format 'yyyyMMdd_HHmmss'"') do set TIMESTAMP=%%i

REM Create results directory
set RESULTS_DIR=results\%BENCH%_%GC_NAME%_%TIMESTAMP%
mkdir "%RESULTS_DIR%" 2>nul

echo ========================================
echo ZGC Spring Boot Benchmark (Windows)
echo ========================================
echo Benchmark:  %BENCH%
echo GC:         %GC_NAME%
echo Memory:     %MEM%MB
echo QPS:        %QPS%
echo Duration:   %DURATION%s
echo Warmup:     %WARMUP%s
echo Results:    %RESULTS_DIR%
echo ========================================
echo.

REM Check if JAR exists
set JAR_FILE=target\zgc-springboot-test-1.0.0-SNAPSHOT.jar
if not exist "%JAR_FILE%" (
    echo Building application...
    call mvn clean package -DskipTests -Dquick
    if errorlevel 1 (
        echo Build failed!
        exit /b 1
    )
)

REM JVM options
set JVM_OPTS=-Xms%MEM%m -Xmx%MEM%m
set JVM_OPTS=%JVM_OPTS% %GC_FLAGS%
set JVM_OPTS=%JVM_OPTS% -XX:+AlwaysPreTouch
set JVM_OPTS=%JVM_OPTS% -XX:+UnlockDiagnosticVMOptions
set JVM_OPTS=%JVM_OPTS% -XX:+FlightRecorder
set JVM_OPTS=%JVM_OPTS% -XX:StartFlightRecording=filename="%RESULTS_DIR%\recording.jfr",dumponexit=true,settings=profile

echo Starting application with %GC_NAME%...
echo JVM Options: %JVM_OPTS%
echo.

REM Start the application in a new window
start "ZGC-Test-App" cmd /c "java %JVM_OPTS% -jar %JAR_FILE% > "%RESULTS_DIR%\app.log" 2>&1"

REM Wait for application to start
echo Waiting for application to start...
set /a counter=0
:wait_loop
timeout /t 2 /nobreak >nul
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:%APP_PORT%/api/health' -UseBasicParsing -TimeoutSec 2; exit 0 } catch { exit 1 }" >nul 2>&1
if %errorlevel%==0 goto :app_started
set /a counter+=1
echo   Attempt %counter%/30...
if %counter% geq 30 (
    echo Application failed to start. Check %RESULTS_DIR%\app.log
    type "%RESULTS_DIR%\app.log"
    goto :cleanup
)
goto :wait_loop

:app_started
echo.
echo Application is ready!
echo.

REM Initialize sample data
echo Initializing sample data...
powershell -Command "Invoke-WebRequest -Uri 'http://localhost:%APP_PORT%/api/init?count=1000' -Method POST -UseBasicParsing" >nul 2>&1

echo.
echo Starting load test for %DURATION% seconds at %QPS% QPS...
echo (First %WARMUP% seconds are warmup, results discarded)
echo.

REM Run load test using PowerShell
powershell -ExecutionPolicy Bypass -File run-load-test.ps1 -Duration %DURATION% -Qps %QPS% -Endpoint "%ENDPOINT%" -Warmup %WARMUP% -ResultsDir "%RESULTS_DIR%"

goto :cleanup

:show_help
echo Usage: bench.bat [OPTIONS]
echo.
echo Options:
echo   --duration SEC    Test duration in seconds (default: 120)
echo   --bench TYPE      Benchmark type: random, compute (default: random)
echo   --mem MB          Heap memory in MB (default: 4096)
echo   --qps NUM         Requests per second (default: 1000)
echo   --gc TYPE         GC type: G1, ZGC, GenZGC (default: G1)
echo   --warmup SEC      Warmup period in seconds (default: 30)
echo   -h, --help        Show this help message
echo.
echo Examples:
echo   bench.bat --duration 120 --bench random --mem 4096 --qps 1000 --gc G1
echo   bench.bat --gc ZGC --qps 2000
exit /b 0

:cleanup
echo.
echo Stopping application...
REM Find and kill Java process running our JAR
powershell -Command "Get-Process java -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*zgc-springboot-test*' } | Stop-Process -Force -ErrorAction SilentlyContinue"
REM Also try to kill by window title
taskkill /FI "WINDOWTITLE eq ZGC-Test-App*" /F >nul 2>&1
REM Give it a moment
timeout /t 2 /nobreak >nul
echo.
echo ========================================
echo Benchmark complete!
echo ========================================
echo Results saved to: %RESULTS_DIR%
echo JFR Recording: %RESULTS_DIR%\recording.jfr
echo.
echo To analyze JFR:
echo   jfr print "%RESULTS_DIR%\recording.jfr"
echo   Or open in JDK Mission Control
echo.
exit /b 0
