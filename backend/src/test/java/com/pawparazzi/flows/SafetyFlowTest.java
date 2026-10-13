package com.pawparazzi.flows;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.ResultActions;

/** Bloquear, reportar y eliminar la cuenta. */
class SafetyFlowTest extends ApiTestSupport {

    @Autowired
    JdbcTemplate jdbc;

    @Value("${pawparazzi.storage.local.root}")
    String storageRoot;

    private void befriend(Account from, Account to) throws Exception {
        JsonNode request = body(sendRequest(from, to).andExpect(status().isOk()));
        mvc.perform(auth(post("/api/v1/friend-requests/" + request.get("id").asText() + "/accept"), to.token()))
                .andExpect(status().isOk());
    }

    private ResultActions sendRequest(Account from, Account to) throws Exception {
        return mvc.perform(auth(post("/api/v1/friend-requests"), from.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("username", to.username()))));
    }

    private ResultActions comment(Account who, UUID postId, String text) throws Exception {
        return mvc.perform(auth(post("/api/v1/posts/" + postId + "/comments"), who.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("body", text))));
    }

    private ResultActions report(Account who, String type, UUID targetId, String reason) throws Exception {
        return mvc.perform(auth(post("/api/v1/reports"), who.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("targetType", type, "targetId", targetId,
                        "reason", reason, "details", "  No me parece apropiado  "))));
    }

    private UUID publishFree(Account author, UUID pet) throws Exception {
        return UUID.fromString(body(publish(author, "FREE", upload(author, "POST"), pet, UUID.randomUUID().toString())
                .andExpect(status().isCreated())).at("/post/id").asText());
    }

    @Test
    void blockingBreaksFriendshipHidesContentAndPreventsNewRequests() throws Exception {
        Account elena = registerWithProfile("Elena");
        Account dani = registerWithProfile("Dani");
        Account lucia = registerWithProfile("Lucia");
        UUID postElena = publishFree(elena, createPet(elena, "Nube"));
        UUID postLucia = publishFree(lucia, createPet(lucia, "Miso"));
        befriend(dani, elena);
        befriend(dani, lucia);
        befriend(elena, lucia);
        comment(dani, postLucia, "Comentario de Dani").andExpect(status().isCreated());

        mvc.perform(auth(get("/api/v1/feed/friends"), dani.token())).andExpect(jsonPath("$.items.length()").value(2));

        // Elena bloquea a Dani (dos veces: es idempotente).
        mvc.perform(auth(put("/api/v1/blocks/" + dani.id()), elena.token())).andExpect(status().isNoContent());
        mvc.perform(auth(put("/api/v1/blocks/" + dani.id()), elena.token())).andExpect(status().isNoContent());
        mvc.perform(auth(get("/api/v1/blocks"), elena.token()))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].user.username").value(dani.username()));

        // Ya no son amigos: ninguno ve lo del otro.
        mvc.perform(auth(get("/api/v1/posts/" + postElena), dani.token())).andExpect(status().isNotFound());
        mvc.perform(auth(get("/api/v1/feed/friends"), dani.token())).andExpect(jsonPath("$.items.length()").value(1));
        mvc.perform(auth(get("/api/v1/friends"), elena.token())).andExpect(jsonPath("$.length()").value(1));

        // Ninguno puede enviar solicitud al otro, y a Dani no se le revela el motivo.
        sendRequest(dani, elena).andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("user_not_found"));
        sendRequest(elena, dani).andExpect(status().isNotFound());

        // En la publicación de Lucía, Elena no ve el comentario de Dani; Lucía sí.
        mvc.perform(auth(get("/api/v1/posts/" + postLucia + "/comments"), elena.token()))
                .andExpect(jsonPath("$.items.length()").value(0));
        mvc.perform(auth(get("/api/v1/posts/" + postLucia + "/comments"), lucia.token()))
                .andExpect(jsonPath("$.items.length()").value(1));

        // Desbloquear permite volver a enviar solicitud, pero no restaura la amistad.
        mvc.perform(auth(delete("/api/v1/blocks/" + dani.id()), elena.token())).andExpect(status().isNoContent());
        mvc.perform(auth(delete("/api/v1/blocks/" + dani.id()), elena.token())).andExpect(status().isNotFound());
        mvc.perform(auth(get("/api/v1/posts/" + postElena), dani.token())).andExpect(status().isNotFound());
        sendRequest(dani, elena).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("PENDING"));

        mvc.perform(auth(put("/api/v1/blocks/" + elena.id()), elena.token())).andExpect(status().isBadRequest());
        mvc.perform(auth(put("/api/v1/blocks/" + UUID.randomUUID()), elena.token())).andExpect(status().isNotFound());
    }

    @Test
    void blockingRejectsPendingRequests() throws Exception {
        Account a = registerWithProfile("Pide");
        Account b = registerWithProfile("Recibe");
        sendRequest(a, b).andExpect(status().isOk());

        mvc.perform(auth(put("/api/v1/blocks/" + a.id()), b.token())).andExpect(status().isNoContent());

        mvc.perform(auth(get("/api/v1/friend-requests?direction=incoming"), b.token()))
                .andExpect(jsonPath("$.length()").value(0));
        mvc.perform(auth(get("/api/v1/friend-requests?direction=outgoing"), a.token()))
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void reportsRequireVisibleContentAndAreNotDuplicated() throws Exception {
        Account elena = registerWithProfile("Elena");
        Account dani = registerWithProfile("Dani");
        Account extra = registerWithProfile("Ajena");
        UUID postId = publishFree(elena, createPet(elena, "Nube"));
        befriend(dani, elena);
        UUID commentId = UUID.fromString(body(comment(elena, postId, "Hola").andExpect(status().isCreated()))
                .get("id").asText());

        String first = body(report(dani, "POST", postId, "NOT_A_PET")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("OPEN"))).get("id").asText();
        String again = body(report(dani, "POST", postId, "SPAM").andExpect(status().isCreated())).get("id").asText();
        assertThat(again).isEqualTo(first);

        report(dani, "COMMENT", commentId, "HARASSMENT").andExpect(status().isCreated());
        report(dani, "USER", elena.id(), "OTHER").andExpect(status().isCreated());

        assertThat(jdbc.queryForObject("select count(*) from reports where reporter_id = ?", Integer.class, dani.id()))
                .isEqualTo(3);
        Map<String, Object> row = jdbc.queryForMap(
                "select reason, details, reported_user_id from reports where id = ?", UUID.fromString(first));
        assertThat(row.get("reason")).isEqualTo("NOT_A_PET");
        assertThat(row.get("details")).isEqualTo("No me parece apropiado");
        assertThat(row.get("reported_user_id")).isEqualTo(elena.id());

        // No se puede reportar lo que no se ve, ni el contenido propio, ni con datos incompletos.
        report(extra, "POST", postId, "SPAM").andExpect(status().isNotFound());
        report(extra, "COMMENT", commentId, "SPAM").andExpect(status().isNotFound());
        report(elena, "POST", postId, "SPAM").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("self_report"));
        report(dani, "USER", UUID.randomUUID(), "SPAM").andExpect(status().isNotFound());
        mvc.perform(auth(post("/api/v1/reports"), dani.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("targetType", "POST", "targetId", postId))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void deletingTheAccountRemovesEverythingIncludingFiles() throws Exception {
        Account elena = registerWithProfile("Elena");
        Account dani = registerWithProfile("Dani");
        UUID petElena = createPet(elena, "Nube");
        UUID postElena = publishFree(elena, petElena);
        UUID momentElena = UUID.fromString(body(publish(elena, "PAW_MOMENT", upload(elena, "POST"), petElena,
                UUID.randomUUID().toString()).andExpect(status().isCreated())).at("/post/id").asText());
        UUID postDani = publishFree(dani, createPet(dani, "Milo"));
        befriend(dani, elena);
        comment(elena, postDani, "Comentario de Elena").andExpect(status().isCreated());
        comment(dani, postElena, "Comentario de Dani").andExpect(status().isCreated());
        mvc.perform(auth(put("/api/v1/posts/" + postDani + "/reactions/me"), elena.token())).andExpect(status().isOk());
        mvc.perform(auth(put("/api/v1/posts/" + momentElena + "/reactions/me"), dani.token())).andExpect(status().isOk());
        report(elena, "POST", postDani, "OTHER").andExpect(status().isCreated());
        report(dani, "POST", postElena, "OTHER").andExpect(status().isCreated());

        Path elenaFiles = Path.of(storageRoot, "media", elena.id().toString());
        assertThat(Files.list(elenaFiles)).hasSize(4); // 2 fotos + 2 miniaturas

        // Sin la contraseña correcta no se borra nada.
        mvc.perform(auth(delete("/api/v1/users/me"), elena.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("password", "incorrecta"))))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("wrong_password"));
        mvc.perform(auth(get("/api/v1/users/me"), elena.token())).andExpect(status().isOk());

        mvc.perform(auth(delete("/api/v1/users/me"), elena.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("password", "contraseña-segura"))))
                .andExpect(status().isNoContent());

        // La cuenta ya no existe: ni con el token aún vigente, ni renovando sesión, ni iniciando sesión.
        mvc.perform(auth(get("/api/v1/users/me"), elena.token())).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", elena.refreshToken()))))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", elena.username() + "@example.com",
                                "password", "contraseña-segura"))))
                .andExpect(status().isUnauthorized());

        // No queda nada suyo en la base de datos...
        for (String query : new String[]{
                "select count(*) from users where id = ?",
                "select count(*) from pets where owner_id = ?",
                "select count(*) from posts where author_id = ?",
                "select count(*) from media_assets where owner_id = ?",
                "select count(*) from comments where author_id = ?",
                "select count(*) from reactions where user_id = ?",
                "select count(*) from daily_participations where user_id = ?",
                "select count(*) from paw_streaks where user_id = ?",
                "select count(*) from refresh_tokens where user_id = ?",
                "select count(*) from friendships where user_low_id = ? or user_high_id = ?",
        }) {
            Object[] args = query.contains("or user_high_id") ? new Object[]{elena.id(), elena.id()} : new Object[]{elena.id()};
            assertThat(jdbc.queryForObject(query, Integer.class, args)).as(query).isZero();
        }
        // ...ni en el almacenamiento.
        assertThat(Files.exists(elenaFiles) ? Files.list(elenaFiles).count() : 0).isZero();

        // Los reportes se conservan sin identificar a la persona eliminada.
        assertThat(jdbc.queryForObject("select count(*) from reports where reporter_id is null and target_id = ?",
                Integer.class, postDani)).isEqualTo(1);
        assertThat(jdbc.queryForObject(
                "select count(*) from reports where reported_user_id is null and target_id = ?",
                Integer.class, postElena)).isEqualTo(1);

        // Lo de Dani sigue intacto, sin rastro de Elena.
        mvc.perform(auth(get("/api/v1/feed/friends"), dani.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].commentCount").value(0))
                .andExpect(jsonPath("$.items[0].reactions.count").value(0));
        mvc.perform(auth(get("/api/v1/friends"), dani.token())).andExpect(jsonPath("$.length()").value(0));
    }
}
