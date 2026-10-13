package com.pawparazzi.safety;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BlockRepository extends JpaRepository<Block, UUID> {

    Optional<Block> findByBlockerIdAndBlockedId(UUID blockerId, UUID blockedId);

    List<Block> findAllByBlockerIdOrderByCreatedAtDesc(UUID blockerId);

    /** Hay bloqueo entre las dos personas, en cualquiera de los dos sentidos. */
    @Query("""
            select count(b) > 0 from Block b
            where (b.blockerId = :a and b.blockedId = :b) or (b.blockerId = :b and b.blockedId = :a)
            """)
    boolean existsBetween(@Param("a") UUID a, @Param("b") UUID b);

    /** Personas con las que hay bloqueo en cualquier sentido (las que bloqueé y las que me bloquearon). */
    @Query("""
            select case when b.blockerId = :userId then b.blockedId else b.blockerId end
            from Block b where b.blockerId = :userId or b.blockedId = :userId
            """)
    List<UUID> counterpartsOf(@Param("userId") UUID userId);
}
