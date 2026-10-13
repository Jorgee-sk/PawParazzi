package com.pawparazzi.media;

import com.pawparazzi.common.config.AppProperties;
import com.pawparazzi.media.storage.StorageService;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.crypto.Mac;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * Enlaces temporales firmados para descargar imágenes sin pasar el token de sesión.
 *
 * <p>Las imágenes son privadas, pero servirlas a través de la API con el token de cada persona
 * obliga al backend a mover todos los bytes. En su lugar, cada respuesta de la API incluye un enlace
 * que caduca:</p>
 * <ul>
 *   <li>Con almacenamiento S3: un enlace prefirmado que lleva al cliente directamente al almacenamiento
 *       (o a una CDN delante de él). El backend no toca los bytes.</li>
 *   <li>Con almacenamiento local: un enlace a la propia API firmado con HMAC.</li>
 * </ul>
 *
 * <p>Solo se generan enlaces para quien puede ver la imagen en ese momento. Quien tenga el enlace puede
 * usarlo hasta que caduque: por eso duran poco y, al caducar, hay que pedir otro (y se vuelve a comprobar
 * el permiso). Tras dejar de ser amigos, los enlaces ya emitidos de fotos que esa persona ya podía ver
 * siguen valiendo hasta su caducidad; no se emiten para fotos nuevas.</p>
 */
@Component
public class MediaLinks {

    public enum Variant { FULL, THUMB }

    /** Identifica una imagen a partir de un enlace emitido antes (para renovarlo). */
    public record Reference(UUID mediaId, Variant variant) {
    }

    private static final Pattern UUID_IN_PATH = Pattern.compile(
            "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})(_thumb)?(\\.jpg|/content)");

    private final StorageService storage;
    private final Duration ttl;
    private final SecretKey signingKey;
    private final Clock clock;

    public MediaLinks(StorageService storage, AppProperties props, SecretKey jwtSecretKey, Clock clock) {
        this.storage = storage;
        this.ttl = props.media().linkTtl();
        this.clock = clock;
        // Clave propia derivada del secreto de la aplicación: no se reutiliza la de los JWT tal cual.
        this.signingKey = new SecretKeySpec(
                hmac(jwtSecretKey, "pawparazzi-media-links-v1".getBytes(StandardCharsets.UTF_8)), "HmacSHA256");
    }

    public static String storageKey(UUID ownerId, UUID mediaId, Variant variant) {
        return "media/" + ownerId + "/" + mediaId + (variant == Variant.THUMB ? "_thumb.jpg" : ".jpg");
    }

    public String full(UUID ownerId, UUID mediaId) {
        return link(ownerId, mediaId, Variant.FULL);
    }

    public String thumbnail(UUID ownerId, UUID mediaId) {
        return link(ownerId, mediaId, Variant.THUMB);
    }

    /** Null si no hay imagen. */
    public String link(UUID ownerId, UUID mediaId, Variant variant) {
        if (mediaId == null || ownerId == null) {
            return null;
        }
        Optional<String> direct = storage.presignedGetUrl(storageKey(ownerId, mediaId, variant), ttl);
        if (direct.isPresent()) {
            return direct.get();
        }
        long expires = clock.instant().plus(ttl).getEpochSecond();
        String variantParam = variant.name().toLowerCase();
        return "/api/v1/media/" + mediaId + "/content?variant=" + variantParam + "&exp=" + expires
                + "&sig=" + signature(mediaId, variantParam, expires);
    }

    /** Valida un enlace a la propia API: firma correcta y sin caducar. */
    public boolean isValid(UUID mediaId, String variant, long expires, String signature) {
        if (signature == null || Instant.ofEpochSecond(expires).isBefore(clock.instant())) {
            return false;
        }
        return MessageDigest.isEqual(
                signature(mediaId, variant, expires).getBytes(StandardCharsets.US_ASCII),
                signature.getBytes(StandardCharsets.US_ASCII));
    }

    public Duration ttl() {
        return ttl;
    }

    /** Extrae la imagen y la variante de un enlace emitido por este servicio (de cualquiera de los dos tipos). */
    public static Optional<Reference> parse(String url) {
        if (url == null) {
            return Optional.empty();
        }
        int query = url.indexOf('?');
        String path = query >= 0 ? url.substring(0, query) : url;
        Matcher m = UUID_IN_PATH.matcher(path);
        Reference last = null;
        while (m.find()) {
            boolean thumb = m.group(2) != null || (m.group(3).equals("/content") && url.contains("variant=thumb"));
            last = new Reference(UUID.fromString(m.group(1)), thumb ? Variant.THUMB : Variant.FULL);
        }
        return Optional.ofNullable(last);
    }

    private String signature(UUID mediaId, String variant, long expires) {
        byte[] mac = hmac(signingKey, (mediaId + "." + variant + "." + expires).getBytes(StandardCharsets.UTF_8));
        return Base64.getUrlEncoder().withoutPadding().encodeToString(mac);
    }

    private static byte[] hmac(SecretKey key, byte[] data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(key);
            return mac.doFinal(data);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
}
