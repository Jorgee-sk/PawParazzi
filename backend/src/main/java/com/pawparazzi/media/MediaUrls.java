package com.pawparazzi.media;

import java.util.UUID;

/** Rutas relativas a la API; el cliente las resuelve contra su URL base y envía su token. */
public final class MediaUrls {

    private MediaUrls() {
    }

    public static String full(UUID mediaId) {
        return mediaId == null ? null : "/api/v1/media/" + mediaId;
    }

    public static String thumbnail(UUID mediaId) {
        return mediaId == null ? null : "/api/v1/media/" + mediaId + "?variant=thumb";
    }
}
