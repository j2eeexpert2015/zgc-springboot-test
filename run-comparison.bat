@echo off
REM ===========================================
REM Run GC Comparison Benchmark - Windows
REM Compares G1GC, ZGC, and Generational ZGC
REM ===========================================

setlocal enabledelayedexpansion

REM Default values
set DURATION=120
set QPS=1000
set MEM=4096
set BENCH=random

REM Parse arguments
:parse_args
if "%~1"=="" goto :done_parsing
if "%~1"=="--duration" (set DURATION=%~2& shift & shift & goto :parse_args)
if "%~1"=="--qps" (set QPS=%~2& shift & shift & goto :parse_args)
if "%~1"=="--mem" (set MEM=%~2& shift & shift & goto :parse_args)
if "%~1"=="--bench" (set BENCH=%~2& shift & shift & goto :parse_args)
if "%~1"=="--help" goto :show_help
if "%~1"=="-h" goto :show_help
shift
goto :parse_args
:done_parsing

echo ============================================
echo GC Comparison Benchmark (Windows)
echo ============================================
echo Duration:   %DURATION%s
echo QPS:        %QPS%
echo Memory:     %MEM%MB
echo Benchmark:  %BENCH%
echo ============================================
echo.

REM Build application
echo Building application...
call mvn clean package -DskipTests -Dquick
if errorlevel 1 (
    echo Build failed!
    exit /b 1
)
echo Build complete!
echo.

REM Run G1GC
echo ============================================
echo Running benchmark with G1GC...
echo ============================================
call bench.bat --duration %DURATION% --qps %QPS% --mem %MEM% --bench %BENCH% --gc G1
echo.
echo Waiting 10 seconds before next test...
timeout /t 10 /nobreak >nul

REM Run ZGC
echo ============================================
echo Running benchmark with ZGC...
echo ============================================
call bench.bat --duration %DURATION% --qps %QPS% --mem %MEM% --bench %BENCH% --gc ZGC
echo.
echo Waiting 10 seconds before next test...
timeout /t 10 /nobreak >nul

REM Run Generational ZGC
echo ============================================
echo Running benchmark with Generational ZGC...
echo ============================================
call bench.bat --duration %DURATION% --qps %QPS% --mem %MEM% --bench %BENCH% --gc GenZGC
echo.

echo ============================================
echo Comparison Complete!
echo ============================================
echo.
echo Results are in the 'results' folder.
echo Compare the summary.txt files from each run.
echo Open recording.jfr files in JDK Mission Control.
echo.
goto :eof

:show_help
echo Usage: run-comparison.bat [OPTIONS]
echo.
echo Options:
echo   --duration SEC    Test duration in seconds (default: 120)
echo   --qps NUM         Requests per second (default: 1000)
echo   --mem MB          Heap memory in MB (default: 4096)
echo   --bench TYPE      Benchmark type: random, compute (default: random)
echo   -h, --help        Show this help message
exit /b 0
