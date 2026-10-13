package com.pawparazzi.reactions;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** "Cariño": una por persona y publicación. Expresa afecto; no suma puntos ni ranking. */
@Entity
@Table(name = "reactions")
public class Reaction {

    @Id
    private UUID id;

    @Column(name = "post_id", nullable = false)
    private UUID postId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected Reaction() {
    }

    public Reaction(UUID postId, UUID userId, Instant now) {
        this.id = UUID.randomUUID();
        this.postId = postId;
        this.userId = userId;
        this.createdAt = now;
    }
}
