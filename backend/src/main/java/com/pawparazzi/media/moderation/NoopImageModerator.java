package com.pawparazzi.media.moderation;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/** Sin proveedor configurado: no se revisa nada y las imágenes quedan marcadas como UNCHECKED. */
@Component
@ConditionalOnProperty(name = "pawparazzi.moderation.provider", havingValue = "none", matchIfMissing = true)
public class NoopImageModerator implements ImageModerator {

    @Override
    public Result review(byte[] jpeg, boolean requireAnimal) {
        return Result.unchecked("none");
    }
}
