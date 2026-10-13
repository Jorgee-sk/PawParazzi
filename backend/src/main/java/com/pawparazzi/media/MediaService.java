package com.pawparazzi.media;

import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.common.config.AppProperties;
import com.pawparazzi.friendships.FriendshipService;
import com.pawparazzi.media.moderation.ImageModerator;
import com.pawparazzi.media.storage.StorageService;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.Clock;
import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class MediaService {

    private static final Logger log = LoggerFactory.getLogger(MediaService.class);

    public static final String CONTENT_TYPE = "image/jpeg";

    /** Origen de los bytes subidos; se lee solo cuando hay hueco para procesar la imagen. */
    @FunctionalInterface
    public interface UploadSource {
        byte[] read() throws IOException;
    }

    public record UploadedMedia(UUID id, String url, String thumbnailUrl, int width, int height) {
    }

    private final MediaAssetRepository repository;
    private final StorageService storage;
    private final ImageProcessor processor;
    private final FriendshipService friendships;
    private final ImageModerator moderator;
    private final boolean rejectWhenModerationFails;
    private final MediaLinks links;
    private final TransactionTemplate tx;
    private final Semaphore processingSlots;
    private final Duration processingWait;
    private final Clock clock;

    public MediaService(MediaAssetRepository repository, StorageService storage, ImageProcessor processor,
                        FriendshipService friendships, ImageModerator moderator, MediaLinks links,
                        PlatformTransactionManager txManager, AppProperties props, Clock clock) {
        this.repository = repository;
        this.storage = storage;
        this.processor = processor;
        this.friendships = friendships;
        this.moderator = moderator;
        this.links = links;
        this.tx = new TransactionTemplate(txManager);
        this.rejectWhenModerationFails = props.moderation() != null && props.moderation().rejectOnError();
        this.processingSlots = new Semaphore(Math.max(1, props.media().maxConcurrentProcessing()), true);
        this.processingWait = props.media().processingWait();
        this.clock = clock;
    }

    /**
     * Sube una imagen. El procesado (decodificar, girar, re-codificar) consume mucha memoria, así que
     * solo se hacen unas pocas a la vez; si no hay hueco tras una espera corta se responde 503 para que
     * el cliente reintente, en lugar de agotar la memoria del servidor.
     *
     * <p>El procesado y la revisión ocurren fuera de la transacción: no se retiene una conexión a la
     * base de datos mientras se trabaja con la imagen.</p>
     */
    public UploadedMedia upload(UUID ownerId, MediaAsset.Purpose purpose, UploadSource source) {
        ImageProcessor.ProcessedImage image = process(source);
        ImageModerator.Result moderation = moderate(image, purpose);
        return tx.execute(status -> store(ownerId, purpose, image, moderation));
    }

    private ImageProcessor.ProcessedImage process(UploadSource source) {
        boolean acquired;
        try {
            acquired = processingSlots.tryAcquire(processingWait.toMillis(), TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            acquired = false;
        }
        if (!acquired) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "server_busy",
                    "Estamos procesando muchas fotos ahora mismo. Inténtalo de nuevo en un momento.");
        }
        try {
            return processor.process(source.read());
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo leer la subida", e);
        } finally {
            processingSlots.release();
        }
    }

    private UploadedMedia store(UUID ownerId, MediaAsset.Purpose purpose, ImageProcessor.ProcessedImage image,
                                ImageModerator.Result moderation) {
        UUID id = UUID.randomUUID();
        String key = MediaLinks.storageKey(ownerId, id, MediaLinks.Variant.FULL);
        String thumbKey = MediaLinks.storageKey(ownerId, id, MediaLinks.Variant.THUMB);
        storage.put(key, image.full(), CONTENT_TYPE);
        storage.put(thumbKey, image.thumbnail(), CONTENT_TYPE);
        // Si la transacción falla tras escribir los ficheros, no dejamos huérfanos en el almacenamiento.
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCompletion(int status) {
                if (status == STATUS_ROLLED_BACK) {
                    storage.delete(key);
                    storage.delete(thumbKey);
                }
            }
        });
        MediaAsset asset = repository.save(new MediaAsset(id, ownerId, purpose, key, thumbKey, CONTENT_TYPE,
                image.width(), image.height(), image.full().length, moderation.status().name(), moderation.provider(),
                clock.instant()));
        return new UploadedMedia(asset.getId(), links.full(ownerId, id), links.thumbnail(ownerId, id),
                asset.getWidth(), asset.getHeight());
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
     * Abre una imagen para servirla desde la propia API. Solo se llama con un enlace firmado ya
     * validado (ver {@link MediaLinks}); se usa cuando el almacenamiento no ofrece enlaces directos.
     */
    @Transactional(readOnly = true)
    public StorageService.StoredObject open(UUID mediaId, MediaLinks.Variant variant) {
        MediaAsset asset = repository.findById(mediaId).orElseThrow(MediaService::notFound);
        String key = variant == MediaLinks.Variant.THUMB ? asset.getThumbnailKey() : asset.getStorageKey();
        return storage.open(key).orElseThrow(MediaService::notFound);
    }

    /**
     * Renueva un enlace caducado. Aquí se vuelve a aplicar la política de acceso: la persona
     * propietaria y sus amistades. Lo ajeno responde 404, sin revelar si existe.
     */
    @Transactional(readOnly = true)
    public String refreshLink(UUID viewerId, String url) {
        MediaLinks.Reference reference = MediaLinks.parse(url).orElseThrow(MediaService::notFound);
        MediaAsset asset = repository.findById(reference.mediaId()).orElseThrow(MediaService::notFound);
        if (!asset.getOwnerId().equals(viewerId) && !friendships.areFriends(asset.getOwnerId(), viewerId)) {
            throw notFound();
        }
        return links.link(asset.getOwnerId(), asset.getId(), reference.variant());
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
