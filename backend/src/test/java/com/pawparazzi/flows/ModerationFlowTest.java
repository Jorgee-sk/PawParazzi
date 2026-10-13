package com.pawparazzi.flows;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.pawparazzi.media.ImageProcessorTest;
import com.pawparazzi.media.MediaAssetRepository;
import com.pawparazzi.media.moderation.ImageModerator;
import com.pawparazzi.media.moderation.ImageModerator.Reason;
import com.pawparazzi.media.moderation.ImageModerator.Result;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.ResultActions;

/** La subida respeta el veredicto del revisor de imágenes, sea cual sea el proveedor. */
class ModerationFlowTest extends ApiTestSupport {

    @MockitoBean
    ImageModerator moderator;

    @Autowired
    MediaAssetRepository mediaAssets;

    private ResultActions uploadAs(Account a, String purpose) throws Exception {
        MockMultipartFile file = new MockMultipartFile("file", "foto.jpg", "image/jpeg",
                ImageProcessorTest.TestImages.jpeg(64, 48));
        return mvc.perform(auth(multipart("/api/v1/media").file(file).param("purpose", purpose), a.token()));
    }

    @Test
    void approvedImagesAreStoredAndMarked() throws Exception {
        when(moderator.review(any(), anyBoolean())).thenReturn(Result.approved("fake"));
        Account a = registerWithProfile("Aprobada");

        String id = body(uploadAs(a, "POST").andExpect(status().isCreated())).get("id").asText();

        assertThat(mediaAssets.findById(UUID.fromString(id)).orElseThrow().getModerationStatus()).isEqualTo("APPROVED");
        verify(moderator).review(any(), eq(true));
    }

    @Test
    void rejectedImagesAreNotStoredAndExplainWhy() throws Exception {
        when(moderator.review(any(), anyBoolean())).thenReturn(Result.rejected(Reason.NOT_AN_ANIMAL, "fake"));
        Account a = registerWithProfile("Rechazada");
        long before = mediaAssets.count();

        uploadAs(a, "POST")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("image_rejected"))
                .andExpect(jsonPath("$.message").value(Reason.NOT_AN_ANIMAL.userMessage()));

        assertThat(mediaAssets.count()).isEqualTo(before);
    }

    @Test
    void personAvatarOnlyNeedsToBeSafe() throws Exception {
        when(moderator.review(any(), anyBoolean())).thenReturn(Result.approved("fake"));
        Account a = registerWithProfile("Avatar");

        uploadAs(a, "USER_AVATAR").andExpect(status().isCreated());

        verify(moderator).review(any(), eq(false));
    }

    @Test
    void whenTheReviewerFailsTheUploadIsAcceptedAsUnchecked() throws Exception {
        // Política por defecto (on-error: allow): la IA nunca impide publicar si falla.
        when(moderator.review(any(), anyBoolean()))
                .thenThrow(new ImageModerator.ModerationUnavailableException("caído", null));
        Account a = registerWithProfile("Caido");

        String id = body(uploadAs(a, "POST").andExpect(status().isCreated())).get("id").asText();

        assertThat(mediaAssets.findById(UUID.fromString(id)).orElseThrow().getModerationStatus()).isEqualTo("UNCHECKED");
    }
}
