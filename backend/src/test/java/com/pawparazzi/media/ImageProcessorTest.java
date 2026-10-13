package com.pawparazzi.media;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.pawparazzi.common.config.AppProperties;
import com.pawparazzi.common.error.ApiException;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;

public class ImageProcessorTest {

    private final ImageProcessor processor = new ImageProcessor(new AppProperties(null, null, null, null,
            new AppProperties.Media(10 * 1024 * 1024, 50_000_000, 2048, 480, 0.85f, java.time.Duration.ofHours(1), 2,
                    java.time.Duration.ofSeconds(1)), null, null));

    @Test
    void stripsExifAndAppliesOrientation() throws IOException {
        byte[] withExif = TestImages.jpegWithExifOrientation(400, 200, 6);
        assertThat(contains(withExif, "Exif")).isTrue();

        ImageProcessor.ProcessedImage result = processor.process(withExif);

        assertThat(contains(result.full(), "Exif")).isFalse();
        assertThat(hasApp1Marker(result.full())).isFalse();
        // Orientación 6 = girar 90°: el ancho y el alto se intercambian.
        assertThat(result.width()).isEqualTo(200);
        assertThat(result.height()).isEqualTo(400);
        BufferedImage thumb = ImageIO.read(new ByteArrayInputStream(result.thumbnail()));
        assertThat(Math.max(thumb.getWidth(), thumb.getHeight())).isLessThanOrEqualTo(480);
    }

    @Test
    void downscalesLargeImages() throws IOException {
        ImageProcessor.ProcessedImage result = processor.process(TestImages.png(3000, 1500));
        assertThat(result.width()).isEqualTo(2048);
        assertThat(result.height()).isEqualTo(1024);
    }

    @Test
    void rejectsContentThatIsNotAnImageRegardlessOfName() {
        byte[] fake = "<?php echo 'hola'; ?>".getBytes(StandardCharsets.UTF_8);
        assertThatThrownBy(() -> processor.process(fake))
                .isInstanceOf(ApiException.class)
                .extracting(e -> ((ApiException) e).code()).isEqualTo("unsupported_image");
    }

    @Test
    void rejectsTruncatedJpeg() throws IOException {
        byte[] jpeg = TestImages.jpeg(100, 100);
        byte[] truncated = java.util.Arrays.copyOf(jpeg, 20);
        assertThatThrownBy(() -> processor.process(truncated)).isInstanceOf(ApiException.class);
    }

    private static boolean contains(byte[] data, String text) {
        byte[] needle = text.getBytes(StandardCharsets.US_ASCII);
        outer:
        for (int i = 0; i <= data.length - needle.length; i++) {
            for (int j = 0; j < needle.length; j++) {
                if (data[i + j] != needle[j]) {
                    continue outer;
                }
            }
            return true;
        }
        return false;
    }

    private static boolean hasApp1Marker(byte[] jpeg) {
        for (int i = 0; i < jpeg.length - 1; i++) {
            if ((jpeg[i] & 0xFF) == 0xFF && (jpeg[i + 1] & 0xFF) == 0xE1) {
                return true;
            }
        }
        return false;
    }

    /** Utilidades para generar imágenes de prueba. */
    public static final class TestImages {

        private TestImages() {
        }

        public static byte[] jpeg(int w, int h) throws IOException {
            BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(img, "jpeg", out);
            return out.toByteArray();
        }

        public static byte[] png(int w, int h) throws IOException {
            BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            ImageIO.write(img, "png", out);
            return out.toByteArray();
        }

        /** Inserta un segmento APP1/EXIF mínimo (big-endian) con la etiqueta Orientation tras el SOI. */
        public static byte[] jpegWithExifOrientation(int w, int h, int orientation) throws IOException {
            byte[] base = jpeg(w, h);
            byte[] tiff = {
                    'M', 'M', 0x00, 0x2A, 0, 0, 0, 8,         // cabecera TIFF, IFD0 en offset 8
                    0x00, 0x01,                                // 1 entrada
                    0x01, 0x12, 0x00, 0x03, 0, 0, 0, 1,        // Orientation, SHORT, count 1
                    0x00, (byte) orientation, 0x00, 0x00,      // valor
                    0, 0, 0, 0                                 // sin IFD siguiente
            };
            byte[] header = "Exif\0\0".getBytes(StandardCharsets.US_ASCII);
            int length = 2 + header.length + tiff.length;
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            out.write(base, 0, 2); // SOI
            out.write(0xFF);
            out.write(0xE1);
            out.write((length >> 8) & 0xFF);
            out.write(length & 0xFF);
            out.write(header);
            out.write(tiff);
            out.write(base, 2, base.length - 2);
            return out.toByteArray();
        }
    }
}
