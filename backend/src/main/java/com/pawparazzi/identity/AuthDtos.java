package com.pawparazzi.identity;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public final class AuthDtos {

    private AuthDtos() {
    }

    public record RegisterRequest(
            @NotBlank(message = "Escribe tu email.")
            @Email(message = "Ese email no parece válido.")
            @Size(max = 254)
            String email,
            @NotBlank(message = "Escribe una contraseña.")
            @Size(min = 8, max = 128, message = "Necesita al menos 8 caracteres.")
            String password,
            @Size(max = 64)
            String timeZone) {
    }

    public record LoginRequest(
            @NotBlank(message = "Escribe tu email.") @Size(max = 254) String email,
            @NotBlank(message = "Escribe tu contraseña.") @Size(max = 128) String password) {
    }

    public record RefreshRequest(@NotBlank @Size(max = 200) String refreshToken) {
    }

    public record TokenResponse(String accessToken, Instant accessTokenExpiresAt, String refreshToken,
                                Instant refreshTokenExpiresAt, String tokenType) {
    }
}
