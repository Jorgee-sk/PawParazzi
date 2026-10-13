package com.pawparazzi.flows;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pawparazzi.media.ImageProcessorTest;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
abstract class ApiTestSupport {

    @Autowired
    protected MockMvc mvc;

    @Autowired
    protected ObjectMapper json;

    record Account(UUID id, String token, String refreshToken, String username) {
    }

    protected Account registerWithProfile(String name) throws Exception {
        String unique = name + UUID.randomUUID().toString().substring(0, 8);
        JsonNode tokens = body(mvc.perform(post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of(
                        "email", unique + "@example.com",
                        "password", "contraseña-segura",
                        "timeZone", "Europe/Madrid"))))
                .andExpect(status().isCreated()));
        String token = tokens.get("accessToken").asText();
        String username = unique.toLowerCase();
        JsonNode me = body(mvc.perform(auth(patch("/api/v1/users/me"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("username", username, "displayName", name))))
                .andExpect(status().isOk()));
        return new Account(UUID.fromString(me.get("id").asText()), token, tokens.get("refreshToken").asText(), username);
    }

    protected UUID upload(Account a, String purpose) throws Exception {
        MockMultipartFile file = new MockMultipartFile("file", "foto.jpg", "image/jpeg",
                ImageProcessorTest.TestImages.jpeg(64, 48));
        JsonNode media = body(mvc.perform(auth(multipart("/api/v1/media").file(file).param("purpose", purpose), a.token()))
                .andExpect(status().isCreated()));
        return UUID.fromString(media.get("id").asText());
    }

    protected UUID createPet(Account a, String name) throws Exception {
        JsonNode pet = body(mvc.perform(auth(post("/api/v1/pets"), a.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("name", name, "species", "CAT",
                                "tags", java.util.List.of("Curiosa", "Dormilona")))))
                .andExpect(status().isCreated()));
        return UUID.fromString(pet.get("id").asText());
    }

    protected ResultActions publish(Account a, String type, UUID mediaId, UUID petId, String clientRequestId)
            throws Exception {
        return mvc.perform(auth(post("/api/v1/posts"), a.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of(
                        "type", type,
                        "mediaId", mediaId,
                        "petIds", java.util.List.of(petId),
                        "caption", "El botín del paseo",
                        "tags", java.util.List.of("JUEGO"),
                        "clientRequestId", clientRequestId))));
    }

    protected static <T extends MockHttpServletRequestBuilder> T auth(T builder, String token) {
        builder.header("Authorization", "Bearer " + token);
        return builder;
    }

    protected JsonNode body(ResultActions result) throws Exception {
        return json.readTree(result.andReturn().getResponse().getContentAsByteArray());
    }
}
