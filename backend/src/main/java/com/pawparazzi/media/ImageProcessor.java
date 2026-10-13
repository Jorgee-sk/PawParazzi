package com.pawparazzi.media;

import com.drew.imaging.ImageMetadataReader;
import com.drew.metadata.Metadata;
import com.drew.metadata.exif.ExifIFD0Directory;
import com.pawparazzi.common.config.AppProperties;
import com.pawparazzi.common.error.ApiException;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.AffineTransform;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;
import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.ImageOutputStream;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Valida y normaliza imágenes subidas:
 * <ul>
 *   <li>Detecta el formato por su contenido (firma binaria), nunca por extensión o MIME del cliente.</li>
 *   <li>Rechaza imágenes con demasiados píxeles antes de decodificarlas.</li>
 *   <li>Aplica la orientación EXIF y re-codifica a JPEG sin metadatos: se elimina EXIF (incluido GPS).</li>
 *   <li>Genera una versión completa acotada y una miniatura.</li>
 * </ul>
 */
@Component
public class ImageProcessor {

    public record ProcessedImage(byte[] full, byte[] thumbnail, int width, int height) {
    }

    private final AppProperties.Media config;

    public ImageProcessor(AppProperties props) {
        this.config = props.media();
    }

    public ProcessedImage process(byte[] data) {
        if (data.length == 0) {
            throw ApiException.badRequest("empty_file", "La imagen está vacía.");
        }
        if (data.length > config.maxUploadBytes()) {
            throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "file_too_large",
                    "La imagen supera el tamaño máximo permitido.");
        }
        ImageFormat format = ImageFormat.sniff(data);
        if (format == null) {
            throw new ApiException(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "unsupported_image",
                    "Formato no compatible. Usa una foto JPEG o PNG.");
        }

        BufferedImage decoded = decode(data);
        if (format == ImageFormat.JPEG) {
            decoded = applyOrientation(decoded, readExifOrientation(data));
        }
        BufferedImage rgb = toRgb(decoded);
        BufferedImage full = scaleToFit(rgb, config.maxDimension());
        BufferedImage thumb = scaleToFit(rgb, config.thumbnailDimension());
        return new ProcessedImage(encodeJpeg(full), encodeJpeg(thumb), full.getWidth(), full.getHeight());
    }

    enum ImageFormat {
        JPEG, PNG;

        static ImageFormat sniff(byte[] d) {
            if (d.length >= 3 && (d[0] & 0xFF) == 0xFF && (d[1] & 0xFF) == 0xD8 && (d[2] & 0xFF) == 0xFF) {
                return JPEG;
            }
            if (d.length >= 8 && (d[0] & 0xFF) == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G'
                    && d[4] == 0x0D && d[5] == 0x0A && d[6] == 0x1A && d[7] == 0x0A) {
                return PNG;
            }
            return null;
        }
    }

    private BufferedImage decode(byte[] data) {
        try (ImageInputStream iis = ImageIO.createImageInputStream(new ByteArrayInputStream(data))) {
            Iterator<ImageReader> readers = ImageIO.getImageReaders(iis);
            if (!readers.hasNext()) {
                throw unreadable();
            }
            ImageReader reader = readers.next();
            try {
                reader.setInput(iis, true, true);
                long pixels = (long) reader.getWidth(0) * reader.getHeight(0);
                if (pixels > config.maxPixels()) {
                    throw ApiException.badRequest("image_too_large", "La imagen tiene demasiada resolución.");
                }
                BufferedImage image = reader.read(0);
                if (image == null) {
                    throw unreadable();
                }
                return image;
            } finally {
                reader.dispose();
            }
        } catch (IOException | RuntimeException e) {
            if (e instanceof ApiException api) {
                throw api;
            }
            throw unreadable();
        }
    }

    private static ApiException unreadable() {
        return new ApiException(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "unreadable_image",
                "No pudimos leer la imagen. Prueba con otra foto.");
    }

    static int readExifOrientation(byte[] data) {
        try {
            Metadata metadata = ImageMetadataReader.readMetadata(new ByteArrayInputStream(data));
            ExifIFD0Directory dir = metadata.getFirstDirectoryOfType(ExifIFD0Directory.class);
            if (dir != null && dir.containsTag(ExifIFD0Directory.TAG_ORIENTATION)) {
                return dir.getInt(ExifIFD0Directory.TAG_ORIENTATION);
            }
        } catch (Exception ignored) {
            // Sin EXIF legible: se asume orientación normal.
        }
        return 1;
    }

    /** Orientaciones EXIF 1–8. Las 5–8 intercambian ancho y alto. */
    static BufferedImage applyOrientation(BufferedImage src, int orientation) {
        if (orientation <= 1 || orientation > 8) {
            return src;
        }
        int w = src.getWidth();
        int h = src.getHeight();
        boolean swap = orientation >= 5;
        AffineTransform t = new AffineTransform();
        switch (orientation) {
            case 2 -> { t.scale(-1, 1); t.translate(-w, 0); }
            case 3 -> { t.translate(w, h); t.rotate(Math.PI); }
            case 4 -> { t.scale(1, -1); t.translate(0, -h); }
            case 5 -> { t.rotate(-Math.PI / 2); t.scale(-1, 1); }
            case 6 -> { t.translate(h, 0); t.rotate(Math.PI / 2); }
            case 7 -> { t.scale(-1, 1); t.translate(-h, 0); t.translate(0, w); t.rotate(3 * Math.PI / 2); }
            case 8 -> { t.translate(0, w); t.rotate(3 * Math.PI / 2); }
            default -> { }
        }
        BufferedImage out = new BufferedImage(swap ? h : w, swap ? w : h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = out.createGraphics();
        try {
            g.drawImage(src, t, null);
        } finally {
            g.dispose();
        }
        return out;
    }

    /** JPEG no admite transparencia: se compone sobre blanco. */
    private static BufferedImage toRgb(BufferedImage src) {
        if (src.getType() == BufferedImage.TYPE_INT_RGB) {
            return src;
        }
        BufferedImage out = new BufferedImage(src.getWidth(), src.getHeight(), BufferedImage.TYPE_INT_RGB);
        Graphics2D g = out.createGraphics();
        try {
            g.setColor(Color.WHITE);
            g.fillRect(0, 0, src.getWidth(), src.getHeight());
            g.drawImage(src, 0, 0, null);
        } finally {
            g.dispose();
        }
        return out;
    }

    /** Reducción progresiva (mitades) para conservar calidad sin dependencias externas. */
    static BufferedImage scaleToFit(BufferedImage src, int maxDimension) {
        int w = src.getWidth();
        int h = src.getHeight();
        if (Math.max(w, h) <= maxDimension) {
            return src;
        }
        double scale = (double) maxDimension / Math.max(w, h);
        int targetW = Math.max(1, (int) Math.round(w * scale));
        int targetH = Math.max(1, (int) Math.round(h * scale));
        BufferedImage current = src;
        int cw = w;
        int ch = h;
        while (cw / 2 >= targetW && ch / 2 >= targetH) {
            cw /= 2;
            ch /= 2;
            current = resize(current, cw, ch);
        }
        if (cw != targetW || ch != targetH) {
            current = resize(current, targetW, targetH);
        }
        return current;
    }

    private static BufferedImage resize(BufferedImage src, int w, int h) {
        BufferedImage out = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = out.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
            g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
            g.drawImage(src, 0, 0, w, h, null);
        } finally {
            g.dispose();
        }
        return out;
    }

    /** Escribe JPEG sin bloques de metadatos: el resultado no contiene EXIF ni GPS. */
    private byte[] encodeJpeg(BufferedImage image) {
        ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (ImageOutputStream ios = ImageIO.createImageOutputStream(out)) {
            writer.setOutput(ios);
            ImageWriteParam param = writer.getDefaultWriteParam();
            param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            param.setCompressionQuality(config.jpegQuality());
            writer.write(null, new IIOImage(image, null, null), param);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo codificar la imagen", e);
        } finally {
            writer.dispose();
        }
        return out.toByteArray();
    }
}
