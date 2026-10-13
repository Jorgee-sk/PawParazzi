package com.pawparazzi.reactions;

import com.pawparazzi.common.security.CurrentUserId;
import com.pawparazzi.moments.PostDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/posts/{postId}/reactions/me")
@Tag(name = "Reacciones")
public class ReactionController {

    private final ReactionService service;

    public ReactionController(ReactionService service) {
        this.service = service;
    }

    @Operation(summary = "Envía un cariño (idempotente)")
    @PutMapping
    public PostDtos.ReactionSummary react(@CurrentUserId UUID userId, @PathVariable UUID postId) {
        return service.react(userId, postId);
    }

    @Operation(summary = "Retira tu cariño")
    @DeleteMapping
    public PostDtos.ReactionSummary unreact(@CurrentUserId UUID userId, @PathVariable UUID postId) {
        return service.unreact(userId, postId);
    }
}
