package com.pawparazzi.moments;

import com.pawparazzi.pets.PetDtos;
import com.pawparazzi.users.UserDtos;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class PostDtos {

    private PostDtos() {
    }

    public record CreatePostRequest(
            @NotNull(message = "Indica el tipo de publicación.") Post.Type type,
            @NotNull(message = "Falta la foto.") UUID mediaId,
            @NotEmpty(message = "Elige al menos una mascota.") @Size(max = 10) List<@NotNull UUID> petIds,
            @Size(max = 500, message = "Máximo 500 caracteres.") String caption,
            @Size(max = 7) List<Post.@NotNull Tag> tags,
            /* Generado por el cliente una vez por intento de publicación; los reintentos lo repiten. */
            @NotBlank @Size(max = 64) @Pattern(regexp = "^[A-Za-z0-9-]+$") String clientRequestId) {
    }

    public record UpdatePostRequest(
            @NotEmpty(message = "Elige al menos una mascota.") @Size(max = 10) List<@NotNull UUID> petIds,
            @Size(max = 500, message = "Máximo 500 caracteres.") String caption,
            @Size(max = 7) List<Post.@NotNull Tag> tags) {
    }

    public record ImageView(String url, String thumbnailUrl, int width, int height) {
    }

    public record ReactionSummary(long count, boolean reactedByMe) {
    }

    public record PostView(UUID id, String type, String caption, List<String> tags, Instant createdAt,
                           LocalDate localDate, Boolean onTime, UserDtos.UserSummary author,
                           List<PetDtos.PetSummary> pets, ImageView image, ReactionSummary reactions,
                           long commentCount, boolean isMine) {
    }

    /** Resultado de publicar. {@code streakCounted} indica si esta publicación sumó un día a la racha. */
    public record CreatePostResponse(PostView post, boolean streakCounted, boolean replayed) {
    }

    public record PageResponse<T>(List<T> items, String nextCursor) {
    }

    public record TodayMoment(LocalDate localDate, Instant windowStart, Instant windowEnd, String status,
                              boolean participated, UUID postId) {
    }
}
