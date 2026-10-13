package com.pawparazzi.media;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "media_assets")
public class MediaAsset {

    public enum Purpose { POST, PET_PHOTO, USER_AVATAR }

    @Id
    private UUID id;

    @Column(name = "owner_id", nullable = false)
    private UUID ownerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Purpose purpose;

    @Column(name = "storage_key", nullable = false)
    private String storageKey;

    @Column(name = "thumbnail_key", nullable = false)
    private String thumbnailKey;

    @Column(name = "content_type", nullable = false)
    private String contentType;

    @Column(nullable = false)
    private int width;

    @Column(nullable = false)
    private int height;

    @Column(name = "size_bytes", nullable = false)
    private long sizeBytes;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "moderation_status", nullable = false)
    private String moderationStatus;

    @Column(name = "moderation_provider")
    private String moderationProvider;

    protected MediaAsset() {
    }

    public MediaAsset(UUID id, UUID ownerId, Purpose purpose, String storageKey, String thumbnailKey,
                      String contentType, int width, int height, long sizeBytes, String moderationStatus,
                      String moderationProvider, Instant createdAt) {
        this.id = id;
        this.ownerId = ownerId;
        this.purpose = purpose;
        this.storageKey = storageKey;
        this.thumbnailKey = thumbnailKey;
        this.contentType = contentType;
        this.width = width;
        this.height = height;
        this.sizeBytes = sizeBytes;
        this.moderationStatus = moderationStatus;
        this.moderationProvider = moderationProvider;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getOwnerId() {
        return ownerId;
    }

    public Purpose getPurpose() {
        return purpose;
    }

    public String getStorageKey() {
        return storageKey;
    }

    public String getThumbnailKey() {
        return thumbnailKey;
    }

    public String getContentType() {
        return contentType;
    }

    public int getWidth() {
        return width;
    }

    public String getModerationStatus() {
        return moderationStatus;
    }

    public int getHeight() {
        return height;
    }
}
