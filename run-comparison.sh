#!/bin/bash

# ===========================================
# Run GC Comparison Benchmark
# Compares G1GC, ZGC, and Generational ZGC
# ===========================================

set -e

# Default values
DURATION=120
QPS=1000
MEM=4096
BENCH="random"
WARMUP=30

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --duration SEC    Test duration in seconds (default: $DURATION)"
    echo "  --qps NUM         Requests per second (default: $QPS)"
    echo "  --mem MB          Heap memory in MB (default: $MEM)"
    echo "  --bench TYPE      Benchmark type: random, compute (default: $BENCH)"
    echo "  -h, --help        Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --duration) DURATION="$2"; shift 2 ;;
        --qps) QPS="$2"; shift 2 ;;
        --mem) MEM="$2"; shift 2 ;;
        --bench) BENCH="$2"; shift 2 ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
COMPARISON_DIR="results/comparison_${TIMESTAMP}"
mkdir -p "$COMPARISON_DIR"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}GC Comparison Benchmark${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Duration:   ${GREEN}${DURATION}s${NC}"
echo -e "QPS:        ${GREEN}$QPS${NC}"
echo -e "Memory:     ${GREEN}${MEM}MB${NC}"
echo -e "Benchmark:  ${GREEN}$BENCH${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Build application
echo -e "${YELLOW}Building application...${NC}"
./mvnw clean package -DskipTests -Dquick > /dev/null 2>&1
echo -e "${GREEN}Build complete!${NC}"
echo ""

# Array of GCs to test
GCS=("G1" "ZGC" "GenZGC")

# Run benchmark for each GC
for gc in "${GCS[@]}"; do
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}Running benchmark with $gc...${NC}"
    echo -e "${BLUE}============================================${NC}"
    
    ./bench.sh --duration $DURATION --qps $QPS --mem $MEM --bench $BENCH --gc $gc --warmup $WARMUP
    
    # Copy results to comparison directory
    LATEST_RESULT=$(ls -td results/${BENCH}_${gc}* 2>/dev/null | head -1)
    if [ -d "$LATEST_RESULT" ]; then
        cp -r "$LATEST_RESULT" "$COMPARISON_DIR/"
    fi
    
    echo ""
    echo -e "${GREEN}$gc benchmark complete!${NC}"
    echo ""
    
    # Wait between tests to let system stabilize
    echo -e "${YELLOW}Waiting 10 seconds before next test...${NC}"
    sleep 10
done

# Generate comparison report
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Generating Comparison Report${NC}"
echo -e "${BLUE}============================================${NC}"

REPORT_FILE="$COMPARISON_DIR/comparison_report.txt"

cat > "$REPORT_FILE" << EOF
========================================
GC Comparison Report
Generated: $(date)
========================================

Test Parameters:
- Benchmark: $BENCH
- Duration: ${DURATION}s
- QPS Target: $QPS
- Heap Memory: ${MEM}MB
- Warmup: ${WARMUP}s

========================================
Results Summary
========================================

EOF

for gc in "${GCS[@]}"; do
    RESULT_DIR=$(ls -d "$COMPARISON_DIR"/${BENCH}_${gc}* 2>/dev/null | head -1)
    if [ -d "$RESULT_DIR" ] && [ -f "$RESULT_DIR/summary.txt" ]; then
        echo "--- $gc ---" >> "$REPORT_FILE"
        grep -E "^(Total|Mean|P50|P95|P99|Max)" "$RESULT_DIR/summary.txt" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi
done

echo "" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "Analysis Tips" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
cat >> "$REPORT_FILE" << 'EOF'

1. Compare P99 and P99.9 latencies - ZGC should show significant 
   improvements in tail latencies compared to G1GC.

2. Open the JFR recordings in JDK Mission Control:
   - Look at GC pause times
   - Check for ZAllocationStall events (ZGC only)
   - Compare CPU usage between collectors

3. If ZGC shows worse results than G1:
   - Check for allocation stalls (CPU-bound scenario)
   - Consider increasing heap size
   - Reduce allocation rate in the application

4. JFR Analysis commands:
   jfr print --events jdk.GCPhasePause recording.jfr
   jfr print --events jdk.ZAllocationStall recording.jfr

EOF

cat "$REPORT_FILE"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Comparison Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "Results saved to: ${BLUE}$COMPARISON_DIR${NC}"
echo -e "Report: ${BLUE}$REPORT_FILE${NC}"
echo ""
