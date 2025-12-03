# ZGC Spring Boot Test

A Spring Boot clone of [Gunnar Morling's zgc-test](https://github.com/gunnarmorling/zgc-test) for benchmarking Java garbage collectors. This project demonstrates how different GC implementations (G1GC, ZGC, Generational ZGC) affect tail latencies in a typical microservice workload.

Based on the blog post: [Lower Java Tail Latencies With ZGC](https://www.morling.dev/blog/lower-java-tail-latencies-with-zgc/)

## Prerequisites

- Java 21+ (for Generational ZGC support)
- Docker & Docker Compose
- Maven 3.8+
- Apache JMeter 5.6+

## Quick Start

### 1. Start PostgreSQL

```bash
docker compose up -d
```

### 2. Build the Application

```bash
mvn clean package -DskipTests
```

### 3. Initialize Sample Data

After starting the app (see below), run once:
```bash
curl -X POST "http://localhost:8080/api/init?count=1000"
```

---

## Manual GC Comparison with JMeter

### Step 1: Create JMeter Test Plan

1. Open JMeter
2. Right-click **Test Plan** → Add → Threads → **Thread Group**
    - Number of Threads: `200`
    - Ramp-up period: `30`
    - Loop Count: check **Infinite**
    - Check **Specify Thread lifetime**
    - Duration: `150`

3. Right-click **Thread Group** → Add → Sampler → **HTTP Request**
    - Server Name: `localhost`
    - Port: `8080`
    - Method: `GET`
    - Path: `/api/random?count=10`

4. Right-click **Thread Group** → Add → Listener → **Summary Report**

5. Right-click **Thread Group** → Add → Listener → **Aggregate Report**

6. File → Save As → `zgc-load-test.jmx`

---

### Step 2: Test G1GC

**Terminal 1 - Start app with G1GC + JFR:**
```bash
java -Xms2g -Xmx2g -XX:+UseG1GC -XX:+AlwaysPreTouch -XX:StartFlightRecording=filename=g1gc.jfr,dumponexit=true,settings=profile -jar target/zgc-springboot-test-1.0.0-SNAPSHOT.jar
```

**Terminal 2 - Initialize data (first time only):**
```bash
curl -X POST "http://localhost:8080/api/init?count=1000"
```

**Run JMeter:**
- Open your test plan
- Click Start (green play button)
- Wait for test to complete
- Note down results from Summary Report

**Stop app:** Press `Ctrl+C` (JFR saves automatically)

---

### Step 3: Test Generational ZGC

**Terminal 1 - Start app with ZGC + JFR:**
```bash
java -Xms2g -Xmx2g -XX:+UseZGC -XX:+ZGenerational -XX:+AlwaysPreTouch -XX:StartFlightRecording=filename=zgc.jfr,dumponexit=true,settings=profile -jar target/zgc-springboot-test-1.0.0-SNAPSHOT.jar
```

**Terminal 2 - Initialize data:**
```bash
curl -X POST "http://localhost:8080/api/init?count=1000"
```

**Run JMeter:**
- Click Start
- Wait for test to complete
- Note down results

**Stop app:** Press `Ctrl+C`

---

### Step 4: Compare Results

| Metric | G1GC | ZGC |
|--------|------|-----|
| Avg    |      |     |
| p95    |      |     |
| p99    |      |     |
| Max    |      |     |

---

### Step 5: Analyze JFR in JDK Mission Control

```bash
jmc
```

- File → Open → `g1gc.jfr`
- File → Open → `zgc.jfr`

**What to look for:**

| Recording | Where to Look | Expected |
|-----------|---------------|----------|
| G1GC | Garbage Collections → Pause Durations | 10-50ms pauses |
| ZGC | Garbage Collections → Pause Durations | Sub-millisecond pauses |
| ZGC | Event Browser → search "ZAllocationStall" | Should be zero (if not, system is CPU-bound) |

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/random?count=N` | GET | Get N random items from DB (default: 10) |
| `/api/items` | GET | Get all items |
| `/api/items/{id}` | GET | Get item by ID |
| `/api/compute?iterations=N` | GET | CPU-bound computation (no DB) |
| `/api/health` | GET | Health check |
| `/api/init?count=N` | POST | Initialize sample data |

---

## Expected Results

Based on Gunnar Morling's findings:

| Metric | G1GC | ZGC | Notes |
|--------|------|-----|-------|
| p50 | Similar | Similar | No difference at median |
| p95 | Similar | Similar | Still comparable |
| p99 | Higher | **Lower** | ZGC advantage starts here |
| p99.9 | High | **Much Lower** | Significant improvement |
| Max | Very High | **Low** | Dramatic difference |
| GC Pause | 10-50ms | ~50μs | 400-1000x improvement |

---

## JFR Analysis Commands

```bash
# Print GC pause events
jfr print --events jdk.GCPhasePause g1gc.jfr

# Print ZGC allocation stalls
jfr print --events jdk.ZAllocationStall zgc.jfr

# Summary
jfr summary g1gc.jfr
```

---

## When ZGC Might NOT Help

- **CPU-bound workloads**: ZGC needs CPU headroom for concurrent GC threads
- **Very high allocation rates**: May cause allocation stalls
- **Small heaps**: ZGC overhead may not be worth it

---

## Troubleshooting

### Application won't start
```bash
docker compose ps
docker compose logs postgres
```

### 404 on endpoints
- Check package structure matches `dev.morling.demos.zgc`
- Ensure you ran `curl -X POST "http://localhost:8080/api/init?count=1000"`

### No visible GC differences
- Reduce heap: `-Xms1g -Xmx1g`
- Increase load in JMeter (more threads or longer duration)

---

## References

- [Lower Java Tail Latencies With ZGC](https://www.morling.dev/blog/lower-java-tail-latencies-with-zgc/)
- [Original zgc-test repo](https://github.com/gunnarmorling/zgc-test)
- [ZGC Wiki](https://wiki.openjdk.org/display/zgc)
- [JEP 439: Generational ZGC](https://openjdk.org/jeps/439)