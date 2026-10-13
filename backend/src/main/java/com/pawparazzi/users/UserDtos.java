package com.pawparazzi.users;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class UserDtos {

    private UserDtos() {
    }

    public static final String USERNAME_REGEX = "^[a-z0-9](?:[a-z0-9._]{1,28})[a-z0-9]$";

    public record MeResponse(UUID id, String email, String username, String displayName, String avatarUrl,
                             String timeZone, boolean profileCompleted, long petCount, Instant createdAt) {
    }

    /** Resumen público para amistades, feed y autoría. Nunca incluye email. */
    public record UserSummary(UUID id, String username, String displayName, String avatarUrl) {
    }

    public record UpdateMeRequest(
            @Pattern(regexp = USERNAME_REGEX,
                    message = "3–30 caracteres: minúsculas, números, punto o guion bajo.")
            String username,
            @Size(min = 1, max = 50, message = "Entre 1 y 50 caracteres.")
            String displayName,
            @Size(max = 64)
            String timeZone,
            UUID avatarMediaId) {
    }
}
