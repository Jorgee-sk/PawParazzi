package com.pawparazzi.safety;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "reports")
public class Report {

    public enum TargetType { POST, COMMENT, USER }

    public enum Reason { NOT_A_PET, VIOLENCE, SEXUAL_CONTENT, HARASSMENT, SPAM, OTHER }

    /** OPEN: pendiente de revisión. RESOLVED: se actuó. DISMISSED: no procedía. */
    public enum Status { OPEN, RESOLVED, DISMISSED }

    @Id
    private UUID id;

    @Column(name = "reporter_id")
    private UUID reporterId;

    @Enumerated(EnumType.STRING)
    @Column(name = "target_type", nullable = false)
    private TargetType targetType;

    @Column(name = "target_id", nullable = false)
    private UUID targetId;

    @Column(name = "reported_user_id")
    private UUID reportedUserId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Reason reason;

    private String details;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Status status;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected Report() {
    }

    public Report(UUID reporterId, TargetType targetType, UUID targetId, UUID reportedUserId, Reason reason,
                  String details, Instant now) {
        this.id = UUID.randomUUID();
        this.reporterId = reporterId;
        this.targetType = targetType;
        this.targetId = targetId;
        this.reportedUserId = reportedUserId;
        this.reason = reason;
        this.details = details;
        this.status = Status.OPEN;
        this.createdAt = now;
    }

    public UUID getId() {
        return id;
    }

    public Status getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
