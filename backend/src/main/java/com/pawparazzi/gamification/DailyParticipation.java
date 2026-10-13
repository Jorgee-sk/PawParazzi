package com.pawparazzi.gamification;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "daily_participations")
public class DailyParticipation {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "local_date", nullable = false)
    private LocalDate localDate;

    @Column(name = "post_id")
    private UUID postId;

    @Column(name = "on_time", nullable = false)
    private boolean onTime;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected DailyParticipation() {
    }

    public DailyParticipation(UUID userId, LocalDate localDate, UUID postId, boolean onTime, Instant now) {
        this.id = UUID.randomUUID();
        this.userId = userId;
        this.localDate = localDate;
        this.postId = postId;
        this.onTime = onTime;
        this.createdAt = now;
    }

    public UUID getPostId() {
        return postId;
    }

    public LocalDate getLocalDate() {
        return localDate;
    }
}
