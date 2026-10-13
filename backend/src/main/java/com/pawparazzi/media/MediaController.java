package com.pawparazzi.media;

import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.common.security.CurrentUserId;
import com.pawparazzi.media.storage.StorageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/media")
@Tag(name = "Media")
public class MediaController {

    public record RefreshLinkRequest(@NotBlank @Size(max = 2000) String url) {
    }

    public record LinkResponse(String url) {
    }

    private final MediaService mediaService;
    private final MediaLinks links;
    private final Clock clock;

    public MediaController(MediaService mediaService, MediaLinks links, Clock clock) {
        this.mediaService = mediaService;
        this.links = links;
        this.clock = clock;
    }

    @Operation(summary = "Sube una imagen (JPEG/PNG, máx. 10 MB). Se re-codifica sin EXIF/GPS.",
            description = "503 server_busy si hay demasiadas imágenes procesándose: reintentar.")
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MediaService.UploadedMedia> upload(@CurrentUserId UUID userId,
                                                             @RequestPart("file") MultipartFile file,
                                                             @RequestParam("purpose") MediaAsset.Purpose purpose) {
        if (file.isEmpty()) {
            throw ApiException.badRequest("empty_file", "La imagen está vacía.");
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(mediaService.upload(userId, purpose, file::getBytes));
    }

    @Operation(summary = "Descarga una imagen con un enlace firmado (sin token de sesión)",
            description = "Los enlaces vienen en las respuestas de la API y caducan. Con almacenamiento S3 "
                    + "los enlaces apuntan directamente al almacenamiento y este endpoint no se usa.")
    @GetMapping("/{mediaId}/content")
    public ResponseEntity<InputStreamResource> content(@PathVariable UUID mediaId,
                                                       @RequestParam(defaultValue = "full") String variant,
                                                       @RequestParam long exp,
                                                       @RequestParam String sig) {
        if (!links.isValid(mediaId, variant, exp, sig)) {
            throw ApiException.forbidden("link_expired", "El enlace ha caducado o no es válido.");
        }
        StorageService.StoredObject object = mediaService.open(mediaId,
                "thumb".equals(variant) ? MediaLinks.Variant.THUMB : MediaLinks.Variant.FULL);
        Duration remaining = Duration.between(clock.instant(), Instant.ofEpochSecond(exp));
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_JPEG)
                .contentLength(object.length())
                .cacheControl(CacheControl.maxAge(remaining.isNegative() ? Duration.ZERO : remaining).cachePrivate())
                .header("X-Content-Type-Options", "nosniff")
                .body(new InputStreamResource(object.stream()));
    }

    @Operation(summary = "Renueva un enlace de imagen caducado, si la persona sigue pudiendo verla")
    @PostMapping("/links/refresh")
    public LinkResponse refresh(@CurrentUserId UUID userId, @Valid @RequestBody RefreshLinkRequest request) {
        return new LinkResponse(mediaService.refreshLink(userId, request.url()));
    }
}
