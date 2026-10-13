package com.pawparazzi.identity;

import com.pawparazzi.common.TimeZones;
import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.gamification.StreakService;
import com.pawparazzi.users.User;
import com.pawparazzi.users.UserRepository;
import java.time.Clock;
import java.util.Locale;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository users;
    /** Hash de una contraseña aleatoria: iguala el tiempo de respuesta cuando el email no existe. */
    private final String dummyHash;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokens;
    private final StreakService streaks;
    private final Clock clock;

    public AuthService(UserRepository users, PasswordEncoder passwordEncoder, TokenService tokens,
                       StreakService streaks, Clock clock) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.tokens = tokens;
        this.streaks = streaks;
        this.clock = clock;
        this.dummyHash = passwordEncoder.encode(java.util.UUID.randomUUID().toString());
    }

    @Transactional
    public AuthDtos.TokenResponse register(AuthDtos.RegisterRequest request) {
        String email = normalizeEmail(request.email());
        if (users.existsByEmail(email)) {
            throw ApiException.conflict("email_taken", "Ya existe una cuenta con ese email.");
        }
        String zone = TimeZones.isValid(request.timeZone()) ? request.timeZone() : "UTC";
        User user = new User(email, passwordEncoder.encode(request.password()), zone, clock.instant());
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw ApiException.conflict("email_taken", "Ya existe una cuenta con ese email.");
        }
        streaks.initialize(user.getId());
        return tokens.issue(user.getId());
    }

    @Transactional
    public AuthDtos.TokenResponse login(AuthDtos.LoginRequest request) {
        var user = users.findByEmail(normalizeEmail(request.email()));
        String hash = user.map(User::getPasswordHash).orElse(dummyHash);
        boolean matches = passwordEncoder.matches(request.password(), hash);
        if (user.isEmpty() || !matches) {
            throw ApiException.unauthorized("invalid_credentials", "Email o contraseña incorrectos.");
        }
        return tokens.issue(user.get().getId());
    }

    static String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
