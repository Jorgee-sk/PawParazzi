package com.pawparazzi.media;

import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.io.IOException;
import java.time.Duration;
import java.util.UUID;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/media")
@Tag(name = "Media")
public class MediaController {

    private final MediaService mediaService;

    public MediaController(MediaService mediaService) {
        this.mediaService = mediaService;
    }

    @Operation(summary = "Sube una imagen (JPEG/PNG, máx. 10 MB). Se re-codifica sin EXIF/GPS.")
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<MediaService.UploadedMedia> upload(@CurrentUserId UUID userId,
                                                             @RequestPart("file") MultipartFile file,
                                                             @RequestParam("purpose") MediaAsset.Purpose purpose)
            throws IOException {
        if (file.isEmpty()) {
            throw ApiException.badRequest("empty_file", "La imagen está vacía.");
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(mediaService.upload(userId, purpose, file.getBytes()));
    }

    @Operation(summary = "Descarga una imagen visible para la persona autenticada (propia o de amistades).")
    @GetMapping("/{mediaId}")
    public ResponseEntity<byte[]> download(@CurrentUserId UUID userId, @PathVariable UUID mediaId,
                                           @RequestParam(name = "variant", defaultValue = "full") String variant) {
        MediaService.MediaContent content = mediaService.load(mediaId, userId, "thumb".equals(variant));
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(content.contentType()))
                .cacheControl(CacheControl.maxAge(Duration.ofDays(1)).cachePrivate())
                .header("X-Content-Type-Options", "nosniff")
                .body(content.bytes());
    }
}
