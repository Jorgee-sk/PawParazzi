package com.pawparazzi.media.moderation;

import com.pawparazzi.media.moderation.ImageModerator.Reason;
import com.pawparazzi.media.moderation.ImageModerator.Result;

/**
 * Política de aceptación, independiente del proveedor que mira la foto. El proveedor solo dice
 * qué ve; aquí se decide. La seguridad se comprueba antes que "¿hay un animal?".
 */
public final class ModerationPolicy {

    private ModerationPolicy() {
    }

    /** Lo que se ha observado en la imagen. */
    public record Observation(boolean containsAnimal, boolean violence, boolean sexualContent) {
    }

    public static Result decide(Observation o, boolean requireAnimal, String provider) {
        if (o.violence()) {
            return Result.rejected(Reason.VIOLENCE, provider);
        }
        if (o.sexualContent()) {
            return Result.rejected(Reason.SEXUAL_CONTENT, provider);
        }
        if (requireAnimal && !o.containsAnimal()) {
            return Result.rejected(Reason.NOT_AN_ANIMAL, provider);
        }
        return Result.approved(provider);
    }
}
