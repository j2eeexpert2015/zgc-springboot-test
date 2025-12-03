#!/bin/bash

# ===========================================
# ZGC Spring Boot Benchmark Script
# Inspired by Gunnar Morling's zgc-test
# ===========================================

set -e

# Default values
DURATION=120        # seconds
BENCH="random"      # benchmark type: random, compute
MEM=4096           # heap memory in MB
QPS=1000           # requests per second
GC="G1"            # garbage collector: G1, ZGC, GenZGC
WARMUP=30          # warmup period in seconds (results discarded)
JAVA_HOME=${JAVA_HOME:-$(dirname $(dirname $(readlink -f $(which java))))}
JMETER_HOME=${JMETER_HOME:-/opt/jmeter}
APP_PORT=8080

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --duration SEC    Test duration in seconds (default: $DURATION)"
    echo "  --bench TYPE      Benchmark type: random, compute (default: $BENCH)"
    echo "  --mem MB          Heap memory in MB (default: $MEM)"
    echo "  --qps NUM         Requests per second (default: $QPS)"
    echo "  --gc TYPE         GC type: G1, ZGC, GenZGC (default: $GC)"
    echo "  --warmup SEC      Warmup period in seconds (default: $WARMUP)"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --duration 120 --bench random --mem 4096 --qps 1000 --gc G1"
    echo "  $0 --gc ZGC --qps 2000"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --bench)
            BENCH="$2"
            shift 2
            ;;
        --mem)
            MEM="$2"
            shift 2
            ;;
        --qps)
            QPS="$2"
            shift 2
            ;;
        --gc)
            GC="$2"
            shift 2
            ;;
        --warmup)
            WARMUP="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Determine GC flags
case $GC in
    G1)
        GC_FLAGS="-XX:+UseG1GC"
        GC_NAME="G1GC"
        ;;
    ZGC)
        GC_FLAGS="-XX:+UseZGC"
        GC_NAME="ZGC"
        ;;
    GenZGC)
        GC_FLAGS="-XX:+UseZGC -XX:+ZGenerational"
        GC_NAME="GenZGC"
        ;;
    *)
        echo -e "${RED}Unknown GC type: $GC. Use G1, ZGC, or GenZGC${NC}"
        exit 1
        ;;
esac

# Determine endpoint based on benchmark type
case $BENCH in
    random)
        ENDPOINT="/api/random?count=10"
        ;;
    compute)
        ENDPOINT="/api/compute?iterations=1000"
        ;;
    *)
        echo -e "${RED}Unknown benchmark type: $BENCH. Use random or compute${NC}"
        exit 1
        ;;
esac

# Create results directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="results/${BENCH}_${GC_NAME}_${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ZGC Spring Boot Benchmark${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Benchmark:  ${GREEN}$BENCH${NC}"
echo -e "GC:         ${GREEN}$GC_NAME${NC}"
echo -e "Memory:     ${GREEN}${MEM}MB${NC}"
echo -e "QPS:        ${GREEN}$QPS${NC}"
echo -e "Duration:   ${GREEN}${DURATION}s${NC}"
echo -e "Warmup:     ${GREEN}${WARMUP}s${NC}"
echo -e "Results:    ${GREEN}$RESULTS_DIR${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if application JAR exists
JAR_FILE="target/zgc-springboot-test-1.0.0-SNAPSHOT.jar"
if [ ! -f "$JAR_FILE" ]; then
    echo -e "${YELLOW}Building application...${NC}"
    ./mvnw clean package -DskipTests -Dquick
fi

# Check if Postgres is running
echo -e "${YELLOW}Checking Postgres...${NC}"
if ! docker compose ps | grep -q "zgc-test-postgres.*running"; then
    echo -e "${YELLOW}Starting Postgres...${NC}"
    docker compose up -d
    sleep 5
fi

# Wait for Postgres to be ready
echo -e "${YELLOW}Waiting for Postgres to be ready...${NC}"
for i in {1..30}; do
    if docker compose exec -T postgres pg_isready -U zgcuser -d zgctest > /dev/null 2>&1; then
        echo -e "${GREEN}Postgres is ready!${NC}"
        break
    fi
    sleep 1
done

# JVM options
JVM_OPTS="-Xms${MEM}m -Xmx${MEM}m"
JVM_OPTS="$JVM_OPTS $GC_FLAGS"
JVM_OPTS="$JVM_OPTS -XX:+AlwaysPreTouch"
JVM_OPTS="$JVM_OPTS -XX:+UnlockDiagnosticVMOptions"
JVM_OPTS="$JVM_OPTS -XX:+FlightRecorder"
JVM_OPTS="$JVM_OPTS -XX:StartFlightRecording=filename=${RESULTS_DIR}/recording.jfr,dumponexit=true,settings=profile"

echo -e "${YELLOW}Starting application with $GC_NAME...${NC}"
echo "JVM Options: $JVM_OPTS"
echo ""

# Start the Spring Boot application in background
java $JVM_OPTS -jar "$JAR_FILE" > "${RESULTS_DIR}/app.log" 2>&1 &
APP_PID=$!

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    if [ ! -z "$APP_PID" ] && kill -0 $APP_PID 2>/dev/null; then
        kill $APP_PID 2>/dev/null || true
        wait $APP_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Wait for application to start
echo -e "${YELLOW}Waiting for application to start...${NC}"
for i in {1..60}; do
    if curl -s "http://localhost:${APP_PORT}/api/health" > /dev/null 2>&1; then
        echo -e "${GREEN}Application is ready!${NC}"
        break
    fi
    if ! kill -0 $APP_PID 2>/dev/null; then
        echo -e "${RED}Application failed to start. Check ${RESULTS_DIR}/app.log${NC}"
        exit 1
    fi
    sleep 1
done

# Initialize sample data
echo -e "${YELLOW}Initializing sample data...${NC}"
curl -s -X POST "http://localhost:${APP_PORT}/api/init?count=1000" > /dev/null

# Check if JMeter is available
if [ -x "$JMETER_HOME/bin/jmeter" ]; then
    echo -e "${GREEN}Using JMeter for load testing${NC}"
    USE_JMETER=true
else
    echo -e "${YELLOW}JMeter not found at $JMETER_HOME. Using curl-based load test${NC}"
    USE_JMETER=false
fi

echo ""
echo -e "${BLUE}Starting benchmark...${NC}"
echo -e "${YELLOW}Warmup period: ${WARMUP}s (results will be discarded)${NC}"
echo ""

if [ "$USE_JMETER" = true ]; then
    # Run JMeter test
    $JMETER_HOME/bin/jmeter -n \
        -t jmeter/zgc-benchmark.jmx \
        -JDURATION=$DURATION \
        -JQPS=$QPS \
        -JENDPOINT="$ENDPOINT" \
        -JWARMUP=$WARMUP \
        -l "${RESULTS_DIR}/results.jtl" \
        -j "${RESULTS_DIR}/jmeter.log" \
        -e -o "${RESULTS_DIR}/report"
else
    # Fallback to simple curl-based load test
    echo -e "${YELLOW}Running simple load test with curl...${NC}"
    
    START_TIME=$(date +%s)
    END_TIME=$((START_TIME + DURATION))
    REQUEST_COUNT=0
    ERROR_COUNT=0
    
    # Create a temporary file for latencies
    LATENCY_FILE="${RESULTS_DIR}/latencies.txt"
    
    while [ $(date +%s) -lt $END_TIME ]; do
        # Calculate delay between requests based on QPS
        DELAY=$(echo "scale=6; 1.0 / $QPS" | bc)
        
        # Make request and capture timing
        START_NS=$(date +%s%N)
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${APP_PORT}${ENDPOINT}" || echo "000")
        END_NS=$(date +%s%N)
        
        LATENCY_NS=$((END_NS - START_NS))
        LATENCY_MS=$(echo "scale=3; $LATENCY_NS / 1000000" | bc)
        
        # Only record after warmup period
        ELAPSED=$(($(date +%s) - START_TIME))
        if [ $ELAPSED -ge $WARMUP ]; then
            echo "$LATENCY_MS" >> "$LATENCY_FILE"
        fi
        
        REQUEST_COUNT=$((REQUEST_COUNT + 1))
        if [ "$HTTP_CODE" != "200" ]; then
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
        
        # Progress indicator
        if [ $((REQUEST_COUNT % 1000)) -eq 0 ]; then
            echo -ne "\rRequests: $REQUEST_COUNT | Errors: $ERROR_COUNT | Elapsed: ${ELAPSED}s"
        fi
        
        sleep $DELAY 2>/dev/null || true
    done
    
    echo ""
    echo ""
    
    # Calculate statistics
    if [ -f "$LATENCY_FILE" ]; then
        TOTAL=$(wc -l < "$LATENCY_FILE")
        MEAN=$(awk '{ sum += $1 } END { printf "%.3f", sum/NR }' "$LATENCY_FILE")
        SORTED_FILE="${RESULTS_DIR}/latencies_sorted.txt"
        sort -n "$LATENCY_FILE" > "$SORTED_FILE"
        
        P50=$(awk -v p=0.50 'NR==int(p*FNR+0.5){print}' "$SORTED_FILE")
        P95=$(awk -v p=0.95 'NR==int(p*FNR+0.5){print}' "$SORTED_FILE")
        P99=$(awk -v p=0.99 'NR==int(p*FNR+0.5){print}' "$SORTED_FILE")
        P999=$(awk -v p=0.999 'NR==int(p*FNR+0.5){print}' "$SORTED_FILE")
        MAX=$(tail -1 "$SORTED_FILE")
        MIN=$(head -1 "$SORTED_FILE")
        
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Benchmark Results - $GC_NAME${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo "Total Requests:  $TOTAL"
        echo "Mean Latency:    ${MEAN}ms"
        echo "Min Latency:     ${MIN}ms"
        echo "P50 Latency:     ${P50}ms"
        echo "P95 Latency:     ${P95}ms"
        echo "P99 Latency:     ${P99}ms"
        echo "P99.9 Latency:   ${P999}ms"
        echo "Max Latency:     ${MAX}ms"
        echo -e "${GREEN}========================================${NC}"
        
        # Save summary
        cat > "${RESULTS_DIR}/summary.txt" << EOF
Benchmark: $BENCH
GC: $GC_NAME
Memory: ${MEM}MB
QPS Target: $QPS
Duration: ${DURATION}s
Warmup: ${WARMUP}s

Results:
Total Requests: $TOTAL
Mean Latency: ${MEAN}ms
Min Latency: ${MIN}ms
P50 Latency: ${P50}ms
P95 Latency: ${P95}ms
P99 Latency: ${P99}ms
P99.9 Latency: ${P999}ms
Max Latency: ${MAX}ms
EOF
    fi
fi

echo ""
echo -e "${GREEN}Benchmark complete!${NC}"
echo -e "Results saved to: ${BLUE}$RESULTS_DIR${NC}"
echo -e "JFR Recording:    ${BLUE}${RESULTS_DIR}/recording.jfr${NC}"
echo ""
echo -e "${YELLOW}Analyze JFR with: jfr print ${RESULTS_DIR}/recording.jfr${NC}"
echo -e "${YELLOW}Or open in JDK Mission Control${NC}"
