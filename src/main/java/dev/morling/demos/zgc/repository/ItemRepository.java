package dev.morling.demos.zgc.repository;

import dev.morling.demos.zgc.entity.Item;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ItemRepository extends JpaRepository<Item, Long> {

    /**
     * Find random items - simulates typical database access pattern.
     * This query creates some garbage through result set processing.
     */
    @Query(value = "SELECT * FROM items ORDER BY RANDOM() LIMIT ?1", nativeQuery = true)
    List<Item> findRandomItems(int limit);

    /**
     * Find items with price greater than given value.
     */
    List<Item> findByPriceGreaterThan(java.math.BigDecimal price);
}
