package dev.morling.demos.zgc.controller;

import dev.morling.demos.zgc.service.ItemService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
public class ItemController {

    private static final Logger logger = LoggerFactory.getLogger(ItemController.class);

    private final ItemService itemService;

    // ---------------------------------------------------------
    // IMPORTANT: This constructor is required to initialize the final field
    // ---------------------------------------------------------
    public ItemController(ItemService itemService) {
        this.itemService = itemService;
    }

    /**
     * Main benchmark endpoint - returns random items from database.
     * This is the primary endpoint used in Gunnar's original benchmark.
     *
     * @param count Number of random items to return (default: 10)
     */
    @GetMapping("/random")
    public ResponseEntity<List<Map<String, Object>>> getRandomItems(
            @RequestParam(defaultValue = "10") int count) {

        logger.info("GET /api/random called with count={}", count);
        return ResponseEntity.ok(itemService.getRandomItems(count));
    }

    /**
     * Get item by ID.
     */
    @GetMapping("/items/{id}")
    public ResponseEntity<Map<String, Object>> getItemById(@PathVariable Long id) {

        logger.info("GET /api/items/{} requested", id);

        return itemService.getItemById(id)
                .map(ResponseEntity::ok)
                .orElseGet(() -> {
                    logger.warn("Item with id={} not found", id);
                    return ResponseEntity.notFound().build();
                });
    }

    /**
     * Get all items - useful for generating more GC pressure.
     */
    @GetMapping("/items")
    public ResponseEntity<List<Map<String, Object>>> getAllItems() {

        logger.info("GET /api/items requested");
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

        logger.info("GET /api/compute called with iterations={}", iterations);
        return ResponseEntity.ok(itemService.computeWithGarbage(iterations));
    }

    /**
     * Health check endpoint.
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {

        logger.debug("Health check invoked");
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

        logger.info("Initializing sample data with count={}", count);
        itemService.initializeSampleData(count);

        return ResponseEntity.ok(Map.of(
                "status", "initialized",
                "count", String.valueOf(count)
        ));
    }
}
