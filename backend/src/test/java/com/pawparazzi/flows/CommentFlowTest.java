package com.pawparazzi.flows;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

class CommentFlowTest extends ApiTestSupport {

    private ResultActions comment(Account who, UUID postId, String body) throws Exception {
        return mvc.perform(auth(post("/api/v1/posts/" + postId + "/comments"), who.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("body", body))));
    }

    private void befriend(Account from, Account to) throws Exception {
        JsonNode request = body(mvc.perform(auth(post("/api/v1/friend-requests"), from.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("username", to.username())))));
        mvc.perform(auth(post("/api/v1/friend-requests/" + request.get("id").asText() + "/accept"), to.token()))
                .andExpect(status().isOk());
    }

    @Test
    void friendsCanCommentAndOnlyAuthorsOrPostOwnerCanDelete() throws Exception {
        Account elena = registerWithProfile("Elena");
        Account dani = registerWithProfile("Dani");
        Account lucia = registerWithProfile("Lucia");
        Account extra = registerWithProfile("Ajena");
        UUID pet = createPet(elena, "Nube");
        UUID postId = UUID.fromString(body(publish(elena, "FREE", upload(elena, "POST"), pet,
                UUID.randomUUID().toString())).at("/post/id").asText());

        // Quien no ve la publicación no puede leer ni escribir comentarios.
        comment(extra, postId, "hola").andExpect(status().isNotFound());
        mvc.perform(auth(get("/api/v1/posts/" + postId + "/comments"), extra.token())).andExpect(status().isNotFound());

        befriend(dani, elena);
        befriend(lucia, elena);

        String daniComment = body(comment(dani, postId, "  Qué siesta más absurda  ")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.body").value("Qué siesta más absurda"))
                .andExpect(jsonPath("$.author.username").value(dani.username()))
                .andExpect(jsonPath("$.canDelete").value(true))).get("id").asText();
        String luciaComment = body(comment(lucia, postId, "Nube al poder").andExpect(status().isCreated()))
                .get("id").asText();
        comment(elena, postId, "Gracias").andExpect(status().isCreated());

        comment(dani, postId, "   ").andExpect(status().isBadRequest());
        comment(dani, postId, "x".repeat(501)).andExpect(status().isBadRequest());

        // Orden cronológico; cada persona ve qué puede borrar.
        mvc.perform(auth(get("/api/v1/posts/" + postId + "/comments"), dani.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(3))
                .andExpect(jsonPath("$.items[0].body").value("Qué siesta más absurda"))
                .andExpect(jsonPath("$.items[0].canDelete").value(true))
                .andExpect(jsonPath("$.items[1].canDelete").value(false))
                .andExpect(jsonPath("$.items[2].body").value("Gracias"));

        // El contador llega con la publicación.
        mvc.perform(auth(get("/api/v1/feed/friends"), dani.token()))
                .andExpect(jsonPath("$.items[0].commentCount").value(3));

        // Dani no puede borrar el comentario de Lucía; Elena (dueña de la foto) sí.
        mvc.perform(auth(delete("/api/v1/comments/" + luciaComment), dani.token())).andExpect(status().isForbidden());
        mvc.perform(auth(delete("/api/v1/comments/" + luciaComment), elena.token())).andExpect(status().isNoContent());
        mvc.perform(auth(delete("/api/v1/comments/" + daniComment), dani.token())).andExpect(status().isNoContent());
        mvc.perform(auth(delete("/api/v1/comments/" + daniComment), dani.token())).andExpect(status().isNotFound());

        mvc.perform(auth(get("/api/v1/posts/" + postId), elena.token()))
                .andExpect(jsonPath("$.commentCount").value(1));
    }

    @Test
    void commentsArePaginated() throws Exception {
        Account a = registerWithProfile("Paginas");
        UUID pet = createPet(a, "Miso");
        UUID postId = UUID.fromString(body(publish(a, "FREE", upload(a, "POST"), pet,
                UUID.randomUUID().toString())).at("/post/id").asText());
        for (int i = 1; i <= 3; i++) {
            comment(a, postId, "comentario " + i).andExpect(status().isCreated());
        }
        JsonNode first = body(mvc.perform(auth(get("/api/v1/posts/" + postId + "/comments?limit=2"), a.token())));
        assertThat(first.get("items")).hasSize(2);
        JsonNode second = body(mvc.perform(auth(get("/api/v1/posts/" + postId + "/comments?limit=2&cursor="
                + first.get("nextCursor").asText()), a.token())));
        assertThat(second.get("items")).hasSize(1);
        assertThat(second.at("/items/0/body").asText()).isEqualTo("comentario 3");
        assertThat(second.get("nextCursor")).isNull();
    }
}
