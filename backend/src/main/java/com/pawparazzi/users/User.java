package com.pawparazzi.users;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users")
public class User {

    @Id
    private UUID id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(unique = true)
    private String username;

    @Column(name = "display_name")
    private String displayName;

    @Column(name = "time_zone", nullable = false)
    private String timeZone;

    @Column(name = "avatar_media_id")
    private UUID avatarMediaId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected User() {
    }

    public User(String email, String passwordHash, String timeZone, Instant now) {
        this.id = UUID.randomUUID();
        this.email = email;
        this.passwordHash = passwordHash;
        this.timeZone = timeZone;
        this.createdAt = now;
        this.updatedAt = now;
    }

    /** El perfil se completa en el onboarding (username + nombre visible). */
    public boolean isProfileCompleted() {
        return username != null && displayName != null;
    }

    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getUsername() {
        return username;
    }

    public String getDisplayName() {
        return displayName;
    }

    public String getTimeZone() {
        return timeZone;
    }

    public UUID getAvatarMediaId() {
        return avatarMediaId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setUsername(String username, Instant now) {
        this.username = username;
        this.updatedAt = now;
    }

    public void setDisplayName(String displayName, Instant now) {
        this.displayName = displayName;
        this.updatedAt = now;
    }

    public void setTimeZone(String timeZone, Instant now) {
        this.timeZone = timeZone;
        this.updatedAt = now;
    }

    public void setAvatarMediaId(UUID avatarMediaId, Instant now) {
        this.avatarMediaId = avatarMediaId;
        this.updatedAt = now;
    }
}
