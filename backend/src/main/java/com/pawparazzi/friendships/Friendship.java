package com.pawparazzi.friendships;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Amistad simétrica almacenada una vez, con el par ordenado (low &lt; high). */
@Entity
@Table(name = "friendships")
public class Friendship {

    @Id
    private UUID id;

    @Column(name = "user_low_id", nullable = false)
    private UUID userLowId;

    @Column(name = "user_high_id", nullable = false)
    private UUID userHighId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected Friendship() {
    }

    public Friendship(UUID a, UUID b, Instant now) {
        UUID[] pair = ordered(a, b);
        this.id = UUID.randomUUID();
        this.userLowId = pair[0];
        this.userHighId = pair[1];
        this.createdAt = now;
    }

    /**
     * Orden canónico del par. Debe coincidir con el orden de UUID en la base de datos
     * (PostgreSQL y H2 comparan UUID como bytes sin signo), por eso no usamos UUID.compareTo,
     * que compara con signo.
     */
    static UUID[] ordered(UUID a, UUID b) {
        return unsignedCompare(a, b) < 0 ? new UUID[]{a, b} : new UUID[]{b, a};
    }

    static int unsignedCompare(UUID a, UUID b) {
        int c = Long.compareUnsigned(a.getMostSignificantBits(), b.getMostSignificantBits());
        return c != 0 ? c : Long.compareUnsigned(a.getLeastSignificantBits(), b.getLeastSignificantBits());
    }

    public UUID getUserLowId() {
        return userLowId;
    }

    public UUID getUserHighId() {
        return userHighId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public UUID otherThan(UUID userId) {
        return userLowId.equals(userId) ? userHighId : userLowId;
    }
}
