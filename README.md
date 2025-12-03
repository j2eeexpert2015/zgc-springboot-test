# ZGC Spring Boot Test

A Spring Boot clone of [Gunnar Morling's zgc-test](https://github.com/gunnarmorling/zgc-test) for benchmarking Java garbage collectors. This project demonstrates how different GC implementations (G1GC, ZGC, Generational ZGC) affect tail latencies in a typical microservice workload.

Based on the blog post: [Lower Java Tail Latencies With ZGC](https://www.morling.dev/blog/lower-java-tail-latencies-with-zgc/)

## Prerequisites

- Java 21+ (for Generational ZGC support)
- Docker & Docker Compose
- Maven 3.8+
- (Optional) Apache JMeter 5.6+ for load testing

## Quick Start

### 1. Start PostgreSQL

```bash
docker compose up -d
```

### 2. Build the Application

```bash
./mvnw clean package -Dquick
```

### 3. Run a Benchmark

```bash
# Run with G1GC (default)
./bench.sh --duration 120 --qps 1000 --gc G1

# Run with ZGC
./bench.sh --duration 120 --qps 1000 --gc ZGC

# Run with Generational ZGC (Java 21+)
./bench.sh --duration 120 --qps 1000 --gc GenZGC
```

### 4. Run Full Comparison

```bash
./run-comparison.sh --duration 120 --qps 1000
```

This will run benchmarks with all three GCs and generate a comparison report.

## Project Structure

```
zgc-springboot-test/
├── src/
│   └── main/
│       ├── java/dev/morling/demos/zgc/
│       │   ├── ZgcTestApplication.java    # Spring Boot main class
│       │   ├── controller/
│       │   │   └── ItemController.java    # REST endpoints
│       │   ├── service/
│       │   │   └── ItemService.java       # Business logic with garbage generation
│       │   ├── entity/
│       │   │   └── Item.java              # JPA entity
│       │   └── repository/
│       │       └── ItemRepository.java    # Data access
│       └── resources/
│           └── application.properties     # Configuration
├── jmeter/
│   └── zgc-benchmark.jmx                  # JMeter test plan
├── docker-compose.yml                     # PostgreSQL setup
├── bench.sh                               # Main benchmark script
├── run-comparison.sh                      # Compare all GCs
└── pom.xml
```

## Benchmark Options

```bash
./bench.sh [OPTIONS]

Options:
  --duration SEC    Test duration in seconds (default: 120)
  --bench TYPE      Benchmark type: random, compute (default: random)
  --mem MB          Heap memory in MB (default: 4096)
  --qps NUM         Requests per second (default: 1000)
  --gc TYPE         GC type: G1, ZGC, GenZGC (default: G1)
  --warmup SEC      Warmup period in seconds (default: 30)
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/random?count=N` | GET | Get N random items from DB (default: 10) |
| `/api/items` | GET | Get all items |
| `/api/items/{id}` | GET | Get item by ID |
| `/api/compute?iterations=N` | GET | CPU-bound computation (no DB) |
| `/api/health` | GET | Health check |
| `/api/init?count=N` | POST | Initialize sample data |

## Understanding the Results

### What to Look For

1. **P99 and P99.9 Latencies**: ZGC should show significantly lower tail latencies compared to G1GC.

2. **GC Pause Times**: Open the JFR recording in JDK Mission Control to see actual GC pause durations.

3. **Allocation Stalls**: In CPU-bound scenarios, ZGC may show `ZAllocationStall` events.

### Analyzing JFR Recordings

```bash
# Print GC pause events
jfr print --events jdk.GCPhasePause results/*/recording.jfr

# Print ZGC allocation stalls
jfr print --events jdk.ZAllocationStall results/*/recording.jfr

# Summarize GC events
jfr summary results/*/recording.jfr
```

Or open `recording.jfr` in **JDK Mission Control** for visual analysis.

## Using JMeter

If you have JMeter installed:

```bash
export JMETER_HOME=/path/to/jmeter

# Run via bench.sh (auto-detects JMeter)
./bench.sh --gc ZGC --qps 1000

# Or run JMeter directly
$JMETER_HOME/bin/jmeter -n \
    -t jmeter/zgc-benchmark.jmx \
    -JDURATION=120 \
    -JQPS=1000 \
    -l results.jtl \
    -e -o report/
```

## Expected Results

Based on Gunnar Morling's findings, you should see:

| Metric | G1GC | ZGC | Improvement |
|--------|------|-----|-------------|
| P50 | Similar | Similar | - |
| P99 | Similar | Similar | - |
| P99.9 | High | **Much Lower** | ✅ Significant |
| P99.99 | Very High | **Very Low** | ✅ Dramatic |
| Max GC Pause | ~20-50ms | ~50μs | 400-1000x |

### When ZGC Might NOT Help

- **CPU-bound workloads**: ZGC needs CPU headroom for concurrent GC threads
- **Very high allocation rates**: May cause allocation stalls
- **Small heaps**: ZGC overhead may not be worth it

## Comparison with Original zgc-test

| Feature | Original (Quarkus) | This (Spring Boot) |
|---------|-------------------|-------------------|
| Framework | Quarkus | Spring Boot 3.2 |
| Load Tool | Vegeta | JMeter / curl |
| JFR Support | ✅ | ✅ |
| Database | PostgreSQL | PostgreSQL |
| GC Options | G1, ZGC | G1, ZGC, GenZGC |

## Troubleshooting

### Application won't start
```bash
# Check if Postgres is running
docker compose ps

# View application logs
cat results/*/app.log
```

### High allocation stall count (ZGC)
- Increase heap size: `--mem 8192`
- Reduce QPS: `--qps 500`
- This indicates CPU-bound scenario where G1 may actually perform better

### JMeter not found
- Install JMeter and set `JMETER_HOME`
- Or use the built-in curl-based load generator (automatic fallback)

## References

- [Lower Java Tail Latencies With ZGC](https://www.morling.dev/blog/lower-java-tail-latencies-with-zgc/) - Original blog post
- [Original zgc-test repo](https://github.com/gunnarmorling/zgc-test)
- [ZGC Wiki](https://wiki.openjdk.org/display/zgc)
- [JEP 439: Generational ZGC](https://openjdk.org/jeps/439)

## License

Apache License 2.0
