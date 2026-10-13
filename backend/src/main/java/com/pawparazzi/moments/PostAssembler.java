package com.pawparazzi.moments;

import com.pawparazzi.comments.CommentRepository;
import com.pawparazzi.media.MediaAsset;
import com.pawparazzi.media.MediaAssetRepository;
import com.pawparazzi.media.MediaUrls;
import com.pawparazzi.pets.PetDtos;
import com.pawparazzi.pets.PetService;
import com.pawparazzi.reactions.ReactionRepository;
import com.pawparazzi.users.UserDirectory;
import com.pawparazzi.users.UserDtos;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Convierte publicaciones en vistas cargando autores, mascotas, imágenes y reacciones en lote
 * (un número constante de consultas por página, sin N+1).
 */
@Component
public class PostAssembler {

    private final UserDirectory users;
    private final PetService pets;
    private final MediaAssetRepository media;
    private final ReactionRepository reactions;
    private final CommentRepository comments;

    public PostAssembler(UserDirectory users, PetService pets, MediaAssetRepository media,
                         ReactionRepository reactions, CommentRepository comments) {
        this.users = users;
        this.pets = pets;
        this.media = media;
        this.reactions = reactions;
        this.comments = comments;
    }

    @Transactional(readOnly = true)
    public List<PostDtos.PostView> toViews(List<Post> posts, UUID viewerId) {
        if (posts.isEmpty()) {
            return List.of();
        }
        Set<UUID> postIds = posts.stream().map(Post::getId).collect(Collectors.toSet());
        Map<UUID, UserDtos.UserSummary> authors = users.summaries(
                posts.stream().map(Post::getAuthorId).collect(Collectors.toSet()));
        Set<UUID> petIds = new HashSet<>();
        posts.forEach(p -> petIds.addAll(p.getPetIds()));
        Map<UUID, PetDtos.PetSummary> petSummaries = pets.summaries(petIds);
        Map<UUID, MediaAsset> images = media.findAllByIdIn(
                        posts.stream().map(Post::getMediaId).collect(Collectors.toSet()))
                .stream().collect(Collectors.toMap(MediaAsset::getId, Function.identity()));
        Map<UUID, Long> counts = reactions.countByPostIds(postIds).stream()
                .collect(Collectors.toMap(ReactionRepository.PostCount::getPostId, ReactionRepository.PostCount::getTotal));
        Map<UUID, Long> commentCounts = comments.countByPostIds(postIds).stream()
                .collect(Collectors.toMap(CommentRepository.PostCount::getPostId,
                        CommentRepository.PostCount::getTotal));
        Set<UUID> mine = new HashSet<>(reactions.reactedPostIds(viewerId, postIds));

        return posts.stream().map(p -> {
            MediaAsset image = images.get(p.getMediaId());
            PostDtos.ImageView imageView = image == null ? null : new PostDtos.ImageView(
                    MediaUrls.full(image.getId()), MediaUrls.thumbnail(image.getId()),
                    image.getWidth(), image.getHeight());
            List<PetDtos.PetSummary> postPets = p.getPetIds().stream()
                    .map(petSummaries::get).filter(Objects::nonNull).toList();
            return new PostDtos.PostView(p.getId(), p.getType().name(), p.getCaption(),
                    p.getTags().stream().map(Enum::name).toList(), p.getCreatedAt(), p.getLocalDate(),
                    p.getOnTime(), authors.get(p.getAuthorId()), postPets, imageView,
                    new PostDtos.ReactionSummary(counts.getOrDefault(p.getId(), 0L), mine.contains(p.getId())),
                    commentCounts.getOrDefault(p.getId(), 0L), p.getAuthorId().equals(viewerId));
        }).toList();
    }

    public PostDtos.PostView toView(Post post, UUID viewerId) {
        return toViews(List.of(post), viewerId).getFirst();
    }

    /** Cursor opaco "epochSecond:nano:uuid" en base64url. */
    public static String encodeCursor(Post last) {
        return encodeCursor(last.getCreatedAt(), last.getId());
    }

    public static String encodeCursor(Instant createdAt, UUID id) {
        String raw = createdAt.getEpochSecond() + ":" + createdAt.getNano() + ":" + id;
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    public record Cursor(Instant createdAt, UUID id) {
    }

    public static Cursor decodeCursor(String cursor) {
        try {
            String raw = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
            String[] parts = raw.split(":");
            return new Cursor(Instant.ofEpochSecond(Long.parseLong(parts[0]), Long.parseLong(parts[1])),
                    UUID.fromString(parts[2]));
        } catch (RuntimeException e) {
            throw com.pawparazzi.common.error.ApiException.badRequest("invalid_cursor", "Cursor de paginación no válido.");
        }
    }
}
