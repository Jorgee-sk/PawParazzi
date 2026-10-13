package com.pawparazzi.media.storage;

import java.util.Optional;

/**
 * Almacenamiento de bytes de imágenes fuera de PostgreSQL. La base de datos solo guarda la clave.
 * Implementaciones: {@link LocalStorageService} (desarrollo sin contenedores) y {@link S3StorageService}
 * (SeaweedFS en local con Podman, cualquier proveedor compatible con S3 en producción).
 */
public interface StorageService {

    void put(String key, byte[] content, String contentType);

    Optional<byte[]> get(String key);

    void delete(String key);
}
