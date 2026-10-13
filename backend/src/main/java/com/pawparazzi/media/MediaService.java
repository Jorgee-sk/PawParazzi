package com.pawparazzi.media;

import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.common.config.AppProperties;
import com.pawparazzi.friendships.FriendshipService;
import com.pawparazzi.media.moderation.ImageModerator;
import com.pawparazzi.media.storage.StorageService;
import java.time.Clock;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Service
public class MediaService {

    private static final Logger log = LoggerFactory.getLogger(MediaService.class);

    public static final String CONTENT_TYPE = "image/jpeg";

    public record MediaContent(byte[] bytes, String contentType) {
    }

    public record UploadedMedia(UUID id, String url, String thumbnailUrl, int width, int height) {
        static UploadedMedia of(MediaAsset m) {
            return new UploadedMedia(m.getId(), MediaUrls.full(m.getId()), MediaUrls.thumbnail(m.getId()),
                    m.getWidth(), m.getHeight());
        }
    }

    private final MediaAssetRepository repository;
    private final StorageService storage;
    private final ImageProcessor processor;
    private final FriendshipService friendships;
    private final ImageModerator moderator;
    private final boolean rejectWhenModerationFails;
    private final Clock clock;

    public MediaService(MediaAssetRepository repository, StorageService storage, ImageProcessor processor,
                        FriendshipService friendships, ImageModerator moderator, AppProperties props,
                        Clock clock) {
        this.repository = repository;
        this.storage = storage;
        this.processor = processor;
        this.friendships = friendships;
        this.moderator = moderator;
        this.rejectWhenModerationFails = props.moderation() != null && props.moderation().rejectOnError();
        this.clock = clock;
    }

    @Transactional
    public UploadedMedia upload(UUID ownerId, MediaAsset.Purpose purpose, byte[] data) {
        ImageProcessor.ProcessedImage image = processor.process(data);
        ImageModerator.Result moderation = moderate(image, purpose);
        UUID id = UUID.randomUUID();
        String key = "media/" + ownerId + "/" + id + ".jpg";
        String thumbKey = "media/" + ownerId + "/" + id + "_thumb.jpg";
        storage.put(key, image.full(), CONTENT_TYPE);
        storage.put(thumbKey, image.thumbnail(), CONTENT_TYPE);
        // Si la transacción falla tras escribir los ficheros, no dejamos huérfanos en el almacenamiento.
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCompletion(int status) {
                    if (status == STATUS_ROLLED_BACK) {
                        storage.delete(key);
                        storage.delete(thumbKey);
                    }
                }
            });
        }
        MediaAsset asset = repository.save(new MediaAsset(id, ownerId, purpose, key, thumbKey, CONTENT_TYPE,
                image.width(), image.height(), image.full().length, moderation.status().name(), moderation.provider(),
                clock.instant()));
        return UploadedMedia.of(asset);
    }

    /**
     * Revisa la imagen antes de guardar nada. Se envía la miniatura (suficiente para clasificar, más
     * rápida y barata). Publicaciones y fotos de mascota deben mostrar un animal; el avatar de persona
     * solo debe ser seguro. Una imagen rechazada no se almacena.
     */
    private ImageModerator.Result moderate(ImageProcessor.ProcessedImage image, MediaAsset.Purpose purpose) {
        boolean requireAnimal = purpose != MediaAsset.Purpose.USER_AVATAR;
        ImageModerator.Result result;
        try {
            result = moderator.review(image.thumbnail(), requireAnimal);
        } catch (ImageModerator.ModerationUnavailableException e) {
            log.warn("Revisión de imagen no disponible: {}", e.getMessage());
            if (rejectWhenModerationFails) {
                throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "moderation_unavailable",
                        "Ahora mismo no podemos revisar la foto. Inténtalo de nuevo en unos minutos.");
            }
            return ImageModerator.Result.unchecked("error");
        }
        if (result.status() == ImageModerator.Status.REJECTED) {
            log.info("Imagen rechazada por la revisión automática: {} ({})", result.reason(), result.provider());
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "image_rejected", result.reason().userMessage());
        }
        return result;
    }

    /**
     * Política de acceso: la persona propietaria y sus amistades. Las imágenes solo se usan en
     * publicaciones, fotos de mascota y avatares, todos visibles únicamente para ese círculo.
     */
    @Transactional(readOnly = true)
    public MediaContent load(UUID mediaId, UUID viewerId, boolean thumbnail) {
        MediaAsset asset = repository.findById(mediaId).orElseThrow(MediaService::notFound);
        if (!asset.getOwnerId().equals(viewerId) && !friendships.areFriends(asset.getOwnerId(), viewerId)) {
            // 404 y no 403: no revelamos la existencia de recursos ajenos.
            throw notFound();
        }
        String key = thumbnail ? asset.getThumbnailKey() : asset.getStorageKey();
        byte[] bytes = storage.get(key).orElseThrow(MediaService::notFound);
        return new MediaContent(bytes, asset.getContentType());
    }

    /** Comprueba que la imagen existe, pertenece a la persona y tiene el propósito esperado. */
    @Transactional(readOnly = true)
    public MediaAsset requireOwned(UUID mediaId, UUID ownerId, MediaAsset.Purpose purpose) {
        MediaAsset asset = repository.findById(mediaId)
                .filter(m -> m.getOwnerId().equals(ownerId))
                .orElseThrow(() -> ApiException.badRequest("invalid_media", "La imagen no existe o no es tuya."));
        if (asset.getPurpose() != purpose) {
            throw ApiException.badRequest("invalid_media", "La imagen no es válida para este uso.");
        }
        return asset;
    }

    /** Borra metadatos y ficheros. Los ficheros se eliminan solo si la transacción confirma. */
    @Transactional
    public void delete(UUID mediaId) {
        repository.findById(mediaId).ifPresent(asset -> {
            repository.delete(asset);
            Runnable removeFiles = () -> {
                storage.delete(asset.getStorageKey());
                storage.delete(asset.getThumbnailKey());
            };
            if (TransactionSynchronizationManager.isSynchronizationActive()) {
                TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                    @Override
                    public void afterCommit() {
                        removeFiles.run();
                    }
                });
            } else {
                removeFiles.run();
            }
        });
    }

    private static ApiException notFound() {
        return ApiException.notFound("media_not_found", "Imagen no encontrada.");
    }
}
