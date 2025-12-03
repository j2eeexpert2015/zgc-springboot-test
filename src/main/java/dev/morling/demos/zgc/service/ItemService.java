package dev.morling.demos.zgc.service;

import dev.morling.demos.zgc.entity.Item;
import dev.morling.demos.zgc.repository.ItemRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Service layer that performs database operations and generates garbage.
 * This simulates typical microservice behavior that puts pressure on the GC.
 */
@Service
@RequiredArgsConstructor
public class ItemService {

    private final ItemRepository itemRepository;
    private final Random random = new Random();

    /**
     * Get random items from database.
     * Creates intermediate objects to simulate real-world processing.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getRandomItems(int count) {
        List<Item> items = itemRepository.findRandomItems(count);
        
        // Transform to maps - creates garbage (similar to JSON serialization overhead)
        return items.stream()
                .map(this::itemToMap)
                .collect(Collectors.toList());
    }

    /**
     * Get a single item by ID with some additional processing.
     */
    @Transactional(readOnly = true)
    public Optional<Map<String, Object>> getItemById(Long id) {
        return itemRepository.findById(id)
                .map(this::itemToMap);
    }

    /**
     * Get all items - can create significant garbage with large datasets.
     */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> getAllItems() {
        return itemRepository.findAll().stream()
                .map(this::itemToMap)
                .collect(Collectors.toList());
    }

    /**
     * Perform a computation that generates garbage.
     * This simulates business logic that creates temporary objects.
     */
    public Map<String, Object> computeWithGarbage(int iterations) {
        List<Long> numbers = new ArrayList<>();
        
        // Generate random numbers - creates garbage
        for (int i = 0; i < iterations; i++) {
            numbers.add(random.nextLong());
        }
        
        // Process numbers - creates more garbage through boxing/unboxing
        long sum = numbers.stream()
                .mapToLong(Long::longValue)
                .sum();
        
        double average = numbers.stream()
                .mapToLong(Long::longValue)
                .average()
                .orElse(0.0);
        
        // Sort creates temporary arrays
        List<Long> sorted = numbers.stream()
                .sorted()
                .collect(Collectors.toList());
        
        Map<String, Object> result = new HashMap<>();
        result.put("iterations", iterations);
        result.put("sum", sum);
        result.put("average", average);
        result.put("min", sorted.isEmpty() ? 0 : sorted.get(0));
        result.put("max", sorted.isEmpty() ? 0 : sorted.get(sorted.size() - 1));
        result.put("timestamp", System.currentTimeMillis());
        
        return result;
    }

    /**
     * Initialize sample data.
     */
    @Transactional
    public void initializeSampleData(int count) {
        if (itemRepository.count() > 0) {
            return; // Already initialized
        }
        
        List<Item> items = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            Item item = new Item();
            item.setName("Item-" + i);
            item.setDescription("Description for item " + i + ". " + generateRandomDescription());
            item.setPrice(BigDecimal.valueOf(random.nextDouble() * 1000).setScale(2, BigDecimal.ROUND_HALF_UP));
            item.setQuantity(random.nextInt(1000));
            items.add(item);
        }
        
        itemRepository.saveAll(items);
    }

    private Map<String, Object> itemToMap(Item item) {
        Map<String, Object> map = new HashMap<>();
        map.put("id", item.getId());
        map.put("name", item.getName());
        map.put("description", item.getDescription());
        map.put("price", item.getPrice());
        map.put("quantity", item.getQuantity());
        map.put("createdAt", item.getCreatedAt());
        map.put("updatedAt", item.getUpdatedAt());
        // Add some computed fields - creates more garbage
        map.put("totalValue", item.getPrice().multiply(BigDecimal.valueOf(item.getQuantity())));
        map.put("inStock", item.getQuantity() > 0);
        return map;
    }

    private String generateRandomDescription() {
        String[] words = {"excellent", "premium", "quality", "affordable", "durable", 
                         "lightweight", "compact", "versatile", "reliable", "innovative"};
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 10; i++) {
            sb.append(words[random.nextInt(words.length)]).append(" ");
        }
        return sb.toString().trim();
    }
}
