package com.pawparazzi.safety;

import com.pawparazzi.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Tag(name = "Seguridad: bloqueos y reportes")
public class SafetyController {

    public record ReportRequest(
            @NotNull(message = "Indica qué reportas.") Report.TargetType targetType,
            @NotNull UUID targetId,
            @NotNull(message = "Elige un motivo.") Report.Reason reason,
            @Size(max = 500, message = "Máximo 500 caracteres.") String details) {
    }

    private final BlockService blocks;
    private final ReportService reports;

    public SafetyController(BlockService blocks, ReportService reports) {
        this.blocks = blocks;
        this.reports = reports;
    }

    @Operation(summary = "Personas que he bloqueado")
    @GetMapping("/blocks")
    public List<BlockService.BlockedView> blocked(@CurrentUserId UUID userId) {
        return blocks.listBlocked(userId);
    }

    @Operation(summary = "Bloquea a una persona (idempotente): rompe la amistad e impide nuevas solicitudes")
    @PutMapping("/blocks/{targetId}")
    public ResponseEntity<Void> block(@CurrentUserId UUID userId, @PathVariable UUID targetId) {
        blocks.block(userId, targetId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Desbloquea a una persona (no restaura la amistad)")
    @DeleteMapping("/blocks/{targetId}")
    public ResponseEntity<Void> unblock(@CurrentUserId UUID userId, @PathVariable UUID targetId) {
        blocks.unblock(userId, targetId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Reporta una publicación, un comentario o a una persona (sin duplicados)")
    @PostMapping("/reports")
    public ResponseEntity<ReportService.ReportView> report(@CurrentUserId UUID userId,
                                                           @Valid @RequestBody ReportRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(
                reports.report(userId, request.targetType(), request.targetId(), request.reason(), request.details()));
    }
}
