package com.pawparazzi.media.storage;

import java.io.InputStream;
import java.time.Duration;
import java.util.Optional;

/**
 * Almacenamiento de bytes de imágenes fuera de PostgreSQL. La base de datos solo guarda la clave.
 * Implementaciones: {@link LocalStorageService} (desarrollo sin contenedores) y {@link S3StorageService}
 * (SeaweedFS en local con Podman, cualquier proveedor compatible con S3 en producción).
 */
public interface StorageService {

    /** Contenido abierto para leerlo en streaming; quien lo recibe debe cerrar el stream. */
    record StoredObject(InputStream stream, long length) {
    }

    void put(String key, byte[] content, String contentType);

    Optional<byte[]> get(String key);

    /** Abre el objeto sin cargarlo entero en memoria. */
    Optional<StoredObject> open(String key);

    void delete(String key);

    /**
     * Enlace temporal para que el cliente descargue el objeto directamente del almacenamiento, sin
     * pasar por la API. Vacío si el proveedor no lo admite (almacenamiento local).
     */
    default Optional<String> presignedGetUrl(String key, Duration ttl) {
        return Optional.empty();
    }
}
