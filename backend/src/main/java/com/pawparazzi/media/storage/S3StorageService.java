package com.pawparazzi.media.storage;

import com.pawparazzi.common.config.AppProperties;
import jakarta.annotation.PreDestroy;
import java.net.URI;
import java.time.Duration;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.NoSuchBucketException;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

/**
 * Almacenamiento compatible con S3: SeaweedFS en local (Podman, ver compose.yaml) o cualquier
 * proveedor S3 en producción. Solo usa operaciones básicas del API S3 para no atarse a ninguno.
 */
@Service
@ConditionalOnProperty(name = "pawparazzi.storage.provider", havingValue = "s3")
public class S3StorageService implements StorageService {

    private static final Logger log = LoggerFactory.getLogger(S3StorageService.class);

    private final S3Client client;
    private final S3Presigner presigner;
    private final String bucket;

    @Autowired
    public S3StorageService(AppProperties props) {
        this(props, buildClient(props.storage().s3()), buildPresigner(props.storage().s3()));
    }

    S3StorageService(AppProperties props, S3Client client, S3Presigner presigner) {
        AppProperties.Storage.S3 s3 = props.storage().s3();
        this.bucket = s3.bucket();
        this.client = client;
        this.presigner = presigner;
        if (s3.createBucketIfMissing()) {
            ensureBucket();
        }
    }

    private static S3Client buildClient(AppProperties.Storage.S3 s3) {
        return S3Client.builder()
                .endpointOverride(URI.create(s3.endpoint()))
                .region(Region.of(s3.region()))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(s3.accessKey(), s3.secretKey())))
                .forcePathStyle(s3.pathStyleAccess())
                .build();
    }

    /**
     * Los enlaces prefirmados se firman para el host público: la firma incluye el host, así que debe
     * ser exactamente la dirección que usará el cliente (el almacenamiento o la CDN que tenga delante).
     */
    private static S3Presigner buildPresigner(AppProperties.Storage.S3 s3) {
        String publicEndpoint = s3.publicEndpoint() == null || s3.publicEndpoint().isBlank()
                ? s3.endpoint() : s3.publicEndpoint();
        return S3Presigner.builder()
                .endpointOverride(URI.create(publicEndpoint))
                .region(Region.of(s3.region()))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(s3.accessKey(), s3.secretKey())))
                .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(s3.pathStyleAccess()).build())
                .build();
    }

    private void ensureBucket() {
        try {
            client.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
        } catch (NoSuchBucketException e) {
            createBucket();
        } catch (S3Exception e) {
            if (e.statusCode() != 404) {
                throw e;
            }
            createBucket();
        }
    }

    private void createBucket() {
        client.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
        log.info("Bucket de imágenes '{}' creado", bucket);
    }

    @Override
    public void put(String key, byte[] content, String contentType) {
        client.putObject(PutObjectRequest.builder().bucket(bucket).key(key).contentType(contentType).build(),
                RequestBody.fromBytes(content));
    }

    @Override
    public Optional<byte[]> get(String key) {
        try {
            return Optional.of(client.getObjectAsBytes(GetObjectRequest.builder().bucket(bucket).key(key).build())
                    .asByteArray());
        } catch (NoSuchKeyException e) {
            return Optional.empty();
        }
    }

    @Override
    public Optional<StoredObject> open(String key) {
        try {
            ResponseInputStream<GetObjectResponse> stream =
                    client.getObject(GetObjectRequest.builder().bucket(bucket).key(key).build());
            return Optional.of(new StoredObject(stream, stream.response().contentLength()));
        } catch (NoSuchKeyException e) {
            return Optional.empty();
        }
    }

    /** Se calcula en local, sin llamar al almacenamiento. */
    @Override
    public Optional<String> presignedGetUrl(String key, Duration ttl) {
        GetObjectPresignRequest request = GetObjectPresignRequest.builder()
                .signatureDuration(ttl)
                .getObjectRequest(GetObjectRequest.builder().bucket(bucket).key(key).build())
                .build();
        return Optional.of(presigner.presignGetObject(request).url().toString());
    }

    @Override
    public void delete(String key) {
        client.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());
    }

    @PreDestroy
    void close() {
        presigner.close();
        client.close();
    }
}
