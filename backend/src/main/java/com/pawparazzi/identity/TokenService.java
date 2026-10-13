package com.pawparazzi.identity;

import com.pawparazzi.common.config.AppProperties;
import com.pawparazzi.common.error.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Access token: JWT HS256 de vida corta (15 min). Refresh token: valor opaco aleatorio de 256 bits,
 * guardado solo como hash SHA-256, con rotación en cada uso. Reutilizar un refresh token ya rotado
 * revoca todas las sesiones de la persona (detección de robo).
 */
@Service
public class TokenService {

    private final JwtEncoder encoder;
    private final RefreshTokenRepository refreshTokens;
    private final AppProperties.Jwt config;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();

    public TokenService(JwtEncoder encoder, RefreshTokenRepository refreshTokens, AppProperties props, Clock clock) {
        this.encoder = encoder;
        this.refreshTokens = refreshTokens;
        this.config = props.jwt();
        this.clock = clock;
    }

    @Transactional
    public AuthDtos.TokenResponse issue(UUID userId) {
        Instant now = clock.instant();
        Instant accessExpires = now.plus(config.accessTokenTtl());
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(config.issuer())
                .subject(userId.toString())
                .issuedAt(now)
                .expiresAt(accessExpires)
                .id(UUID.randomUUID().toString())
                .build();
        String access = encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims))
                .getTokenValue();

        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String refresh = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        Instant refreshExpires = now.plus(config.refreshTokenTtl());
        refreshTokens.save(new RefreshToken(userId, hash(refresh), refreshExpires, now));
        return new AuthDtos.TokenResponse(access, accessExpires, refresh, refreshExpires, "Bearer");
    }

    @Transactional(noRollbackFor = ApiException.class)
    public AuthDtos.TokenResponse rotate(String refreshToken) {
        Instant now = clock.instant();
        RefreshToken stored = refreshTokens.findByHashForUpdate(hash(refreshToken))
                .orElseThrow(TokenService::invalid);
        if (stored.getRevokedAt() != null) {
            // Token ya usado: posible robo. Cerramos todas las sesiones.
            refreshTokens.revokeAllForUser(stored.getUserId(), now);
            throw invalid();
        }
        if (!stored.isUsable(now)) {
            throw invalid();
        }
        stored.revoke(now);
        return issue(stored.getUserId());
    }

    @Transactional
    public void revoke(String refreshToken) {
        refreshTokens.findByHashForUpdate(hash(refreshToken)).ifPresent(t -> t.revoke(clock.instant()));
    }

    static String hash(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static ApiException invalid() {
        return ApiException.unauthorized("invalid_refresh_token", "Tu sesión ha caducado. Vuelve a iniciar sesión.");
    }
}
