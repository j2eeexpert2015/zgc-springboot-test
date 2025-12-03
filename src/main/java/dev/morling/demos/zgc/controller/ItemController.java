package dev.morling.demos.zgc.controller;

import dev.morling.demos.zgc.service.ItemService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * REST Controller exposing endpoints for GC benchmarking.
 * These endpoints are designed to be hit by load testing tools (JMeter, Vegeta, etc.)
 */
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class ItemController {

    private final ItemService itemService;

    /**
     * Main benchmark endpoint - returns random items from database.
     * This is the primary endpoint used in Gunnar's original benchmark.
     * 
     * @param count Number of random items to return (default: 10)
     */
    @GetMapping("/random")
    public ResponseEntity<List<Map<String, Object>>> getRandomItems(
            @RequestParam(defaultValue = "10") int count) {
        return ResponseEntity.ok(itemService.getRandomItems(count));
    }

    /**
     * Get item by ID.
     */
    @GetMapping("/items/{id}")
    public ResponseEntity<Map<String, Object>> getItemById(@PathVariable Long id) {
        return itemService.getItemById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /**
     * Get all items - useful for generating more GC pressure.
     */
    @GetMapping("/items")
    public ResponseEntity<List<Map<String, Object>>> getAllItems() {
        return ResponseEntity.ok(itemService.getAllItems());
    }

    /**
     * Compute endpoint - generates garbage without database access.
     * Useful for isolating GC behavior from database latency.
     * 
     * @param iterations Number of iterations for computation (default: 1000)
     */
    @GetMapping("/compute")
    public ResponseEntity<Map<String, Object>> compute(
            @RequestParam(defaultValue = "1000") int iterations) {
        return ResponseEntity.ok(itemService.computeWithGarbage(iterations));
    }

    /**
     * Health check endpoint.
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "timestamp", String.valueOf(System.currentTimeMillis())
        ));
    }

    /**
     * Initialize sample data (call once before benchmarking).
     * 
     * @param count Number of items to create (default: 1000)
     */
    @PostMapping("/init")
    public ResponseEntity<Map<String, String>> initializeData(
            @RequestParam(defaultValue = "1000") int count) {
        itemService.initializeSampleData(count);
        return ResponseEntity.ok(Map.of(
            "status", "initialized",
            "count", String.valueOf(count)
        ));
    }
}
