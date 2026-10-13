package com.pawparazzi.flows;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

class AuthFlowTest extends ApiTestSupport {

    @Test
    void registerStartsWithIncompleteProfileAndNoPets() throws Exception {
        JsonNode tokens = body(mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", "Elena@Example.com",
                                "password", "12345678", "timeZone", "Europe/Madrid"))))
                .andExpect(status().isCreated()));

        mvc.perform(auth(get("/api/v1/users/me"), tokens.get("accessToken").asText()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("elena@example.com"))
                .andExpect(jsonPath("$.profileCompleted").value(false))
                .andExpect(jsonPath("$.petCount").value(0))
                .andExpect(jsonPath("$.timeZone").value("Europe/Madrid"));

        // Email duplicado (normalizado) → 409
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", "elena@example.com", "password", "12345678"))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("email_taken"));
    }

    @Test
    void validationErrorsAreReportedPerField() throws Exception {
        mvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", "no-es-email", "password", "corta"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"))
                .andExpect(jsonPath("$.fieldErrors.email").exists())
                .andExpect(jsonPath("$.fieldErrors.password").value("Necesita al menos 8 caracteres."));
    }

    @Test
    void loginWithWrongPasswordIsRejectedWithoutRevealingWhichFieldFailed() throws Exception {
        Account a = registerWithProfile("Dani");
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", a.username() + "@example.com",
                                "password", "incorrecta"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("invalid_credentials"));
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", "nadie@example.com", "password", "incorrecta"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("invalid_credentials"));
        mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", a.username() + "@example.com",
                                "password", "contraseña-segura"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty());
    }

    @Test
    void refreshRotatesTokensAndReuseRevokesAllSessions() throws Exception {
        Account a = registerWithProfile("Lucia");
        JsonNode rotated = body(mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", a.refreshToken()))))
                .andExpect(status().isOk()));
        String newRefresh = rotated.get("refreshToken").asText();
        assertThat(newRefresh).isNotEqualTo(a.refreshToken());

        // Reutilizar el token antiguo → 401 y se revocan todas las sesiones (también la nueva).
        mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", a.refreshToken()))))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", newRefresh))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logoutRevokesRefreshToken() throws Exception {
        Account a = registerWithProfile("Sara");
        mvc.perform(post("/api/v1/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", a.refreshToken()))))
                .andExpect(status().isNoContent());
        mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", a.refreshToken()))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void protectedRoutesRequireValidToken() throws Exception {
        mvc.perform(get("/api/v1/users/me")).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("unauthorized"));
        mvc.perform(auth(get("/api/v1/users/me"), "token.falso.firmado")).andExpect(status().isUnauthorized());
    }

    @Test
    void usernameMustBeUniqueAndWellFormed() throws Exception {
        Account a = registerWithProfile("Milo");
        Account b = registerWithProfile("Nala");
        mvc.perform(auth(patch("/api/v1/users/me"), b.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("username", a.username()))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("username_taken"));
        mvc.perform(auth(patch("/api/v1/users/me"), b.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("username", "Con Espacios"))))
                .andExpect(status().isBadRequest());
    }
}
