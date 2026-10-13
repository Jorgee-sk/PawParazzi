package com.pawparazzi.common.error;

import java.time.Instant;
import java.util.Map;

/** Cuerpo uniforme de error de la API. Nunca incluye trazas ni detalles internos. */
public record ApiError(String code, String message, Instant timestamp, Map<String, String> fieldErrors) {

    public static ApiError of(String code, String message) {
        return new ApiError(code, message, Instant.now(), null);
    }
}
