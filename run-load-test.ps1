# ===========================================
# Load Test Script for ZGC Benchmark
# ===========================================

param(
    [int]$Duration = 120,
    [int]$Qps = 1000,
    [string]$Endpoint = "/api/random?count=10",
    [int]$Warmup = 30,
    [string]$ResultsDir = "results"
)

$BaseUrl = "http://localhost:8080"
$Url = "$BaseUrl$Endpoint"

# Initialize arrays for results
$latencies = @()
$errors = 0
$totalRequests = 0

# Calculate delay between requests (in milliseconds)
$delayMs = [math]::Max(1, [int](1000 / $Qps))

Write-Host "Starting load test..."
Write-Host "URL: $Url"
Write-Host "Target QPS: $Qps (delay: ${delayMs}ms)"
Write-Host "Duration: ${Duration}s (Warmup: ${Warmup}s)"
Write-Host ""

$startTime = Get-Date
$endTime = $startTime.AddSeconds($Duration)
$warmupEndTime = $startTime.AddSeconds($Warmup)

# Progress tracking
$lastProgressTime = $startTime

while ((Get-Date) -lt $endTime) {
    $requestStart = Get-Date
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 30 -UseBasicParsing
        $requestEnd = Get-Date
        $latencyMs = ($requestEnd - $requestStart).TotalMilliseconds
        
        # Only record after warmup
        if ((Get-Date) -gt $warmupEndTime) {
            $latencies += $latencyMs
        }
        
        $totalRequests++
    }
    catch {
        $errors++
        $totalRequests++
    }
    
    # Progress update every 5 seconds
    $now = Get-Date
    if (($now - $lastProgressTime).TotalSeconds -ge 5) {
        $elapsed = [int]($now - $startTime).TotalSeconds
        $inWarmup = if ($now -lt $warmupEndTime) { " (warmup)" } else { "" }
        Write-Host "Progress: ${elapsed}s / ${Duration}s | Requests: $totalRequests | Errors: $errors$inWarmup"
        $lastProgressTime = $now
    }
    
    # Delay to maintain QPS
    $elapsed = ((Get-Date) - $requestStart).TotalMilliseconds
    $sleepTime = [math]::Max(0, $delayMs - $elapsed)
    if ($sleepTime -gt 0) {
        Start-Sleep -Milliseconds $sleepTime
    }
}

Write-Host ""
Write-Host "Load test complete!"
Write-Host ""

# Calculate statistics
if ($latencies.Count -gt 0) {
    $sorted = $latencies | Sort-Object
    $count = $sorted.Count
    
    $mean = ($sorted | Measure-Object -Average).Average
    $min = $sorted[0]
    $max = $sorted[$count - 1]
    $p50 = $sorted[[math]::Floor($count * 0.50)]
    $p95 = $sorted[[math]::Floor($count * 0.95)]
    $p99 = $sorted[[math]::Floor($count * 0.99)]
    $p999 = $sorted[[math]::Min($count - 1, [math]::Floor($count * 0.999))]
    
    Write-Host "========================================"
    Write-Host "Benchmark Results"
    Write-Host "========================================"
    Write-Host "Total Requests:  $count (after warmup)"
    Write-Host "Errors:          $errors"
    Write-Host ("Mean Latency:    {0:F3}ms" -f $mean)
    Write-Host ("Min Latency:     {0:F3}ms" -f $min)
    Write-Host ("P50 Latency:     {0:F3}ms" -f $p50)
    Write-Host ("P95 Latency:     {0:F3}ms" -f $p95)
    Write-Host ("P99 Latency:     {0:F3}ms" -f $p99)
    Write-Host ("P99.9 Latency:   {0:F3}ms" -f $p999)
    Write-Host ("Max Latency:     {0:F3}ms" -f $max)
    Write-Host "========================================"
    
    # Save results to file
    $summaryFile = Join-Path $ResultsDir "summary.txt"
    @"
Benchmark Results
=================
Total Requests: $count (after warmup)
Errors: $errors
Mean Latency: $([math]::Round($mean, 3))ms
Min Latency: $([math]::Round($min, 3))ms
P50 Latency: $([math]::Round($p50, 3))ms
P95 Latency: $([math]::Round($p95, 3))ms
P99 Latency: $([math]::Round($p99, 3))ms
P99.9 Latency: $([math]::Round($p999, 3))ms
Max Latency: $([math]::Round($max, 3))ms
"@ | Out-File -FilePath $summaryFile -Encoding UTF8
    
    # Save raw latencies
    $latencyFile = Join-Path $ResultsDir "latencies.txt"
    $latencies | ForEach-Object { "{0:F3}" -f $_ } | Out-File -FilePath $latencyFile -Encoding UTF8
    
    Write-Host ""
    Write-Host "Results saved to: $ResultsDir"
}
else {
    Write-Host "No latency data collected (test may have been too short)"
}
