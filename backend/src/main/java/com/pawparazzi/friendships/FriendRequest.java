package com.pawparazzi.friendships;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "friend_requests")
public class FriendRequest {

    public enum Status { PENDING, ACCEPTED, REJECTED, CANCELLED }

    @Id
    private UUID id;

    @Column(name = "requester_id", nullable = false)
    private UUID requesterId;

    @Column(name = "addressee_id", nullable = false)
    private UUID addresseeId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "responded_at")
    private Instant respondedAt;

    protected FriendRequest() {
    }

    public FriendRequest(UUID requesterId, UUID addresseeId, Instant now) {
        this.id = UUID.randomUUID();
        this.requesterId = requesterId;
        this.addresseeId = addresseeId;
        this.status = Status.PENDING;
        this.createdAt = now;
    }

    public void resolve(Status status, Instant now) {
        this.status = status;
        this.respondedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getRequesterId() {
        return requesterId;
    }

    public UUID getAddresseeId() {
        return addresseeId;
    }

    public Status getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
