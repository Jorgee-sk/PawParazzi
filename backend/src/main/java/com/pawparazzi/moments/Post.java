package com.pawparazzi.moments;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.UUID;

@Entity
@Table(name = "posts")
public class Post {

    /** PawMoment: participación diaria (cuenta para la racha). FREE: Foto libre (PawParazzi Mode). */
    public enum Type { PAW_MOMENT, FREE }

    /** Categorías manuales; el orden coincide con el de los recuerdos en Figma. */
    public enum Tag { DESCANSO, JUEGO, EXTERIOR, TRAVESURAS, INTERACCIONES, ADORABLES, OTRAS }

    @Id
    private UUID id;

    @Column(name = "author_id", nullable = false)
    private UUID authorId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Type type;

    @Column(name = "media_id", nullable = false)
    private UUID mediaId;

    private String caption;

    @Column(name = "local_date", nullable = false)
    private LocalDate localDate;

    /** Solo PawMoment: si se publicó dentro de la ventana. Null en Foto libre. */
    @Column(name = "on_time")
    private Boolean onTime;

    @Column(name = "client_request_id", nullable = false)
    private String clientRequestId;

    @ElementCollection
    @CollectionTable(name = "post_pets", joinColumns = @JoinColumn(name = "post_id"))
    @Column(name = "pet_id")
    private Set<UUID> petIds = new LinkedHashSet<>();

    @ElementCollection
    @CollectionTable(name = "post_tags", joinColumns = @JoinColumn(name = "post_id"))
    @Column(name = "tag")
    @Enumerated(EnumType.STRING)
    private Set<Tag> tags = new LinkedHashSet<>();

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Post() {
    }

    public Post(UUID authorId, Type type, UUID mediaId, String caption, LocalDate localDate, Boolean onTime,
                String clientRequestId, Set<UUID> petIds, Set<Tag> tags, Instant now) {
        this.id = UUID.randomUUID();
        this.authorId = authorId;
        this.type = type;
        this.mediaId = mediaId;
        this.caption = caption;
        this.localDate = localDate;
        this.onTime = onTime;
        this.clientRequestId = clientRequestId;
        this.petIds.addAll(petIds);
        this.tags.addAll(tags);
        this.createdAt = now;
        this.updatedAt = now;
    }

    public void edit(String caption, Set<UUID> petIds, Set<Tag> tags, Instant now) {
        this.caption = caption;
        this.petIds.clear();
        this.petIds.addAll(petIds);
        this.tags.clear();
        this.tags.addAll(tags);
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public UUID getAuthorId() {
        return authorId;
    }

    public Type getType() {
        return type;
    }

    public UUID getMediaId() {
        return mediaId;
    }

    public String getCaption() {
        return caption;
    }

    public LocalDate getLocalDate() {
        return localDate;
    }

    public Boolean getOnTime() {
        return onTime;
    }

    public Set<UUID> getPetIds() {
        return petIds;
    }

    public Set<Tag> getTags() {
        return tags;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
