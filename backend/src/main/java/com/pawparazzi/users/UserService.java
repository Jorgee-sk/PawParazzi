package com.pawparazzi.users;

import com.pawparazzi.common.TimeZones;
import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.media.MediaAsset;
import com.pawparazzi.media.MediaService;
import com.pawparazzi.media.MediaUrls;
import com.pawparazzi.pets.PetRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    private final UserRepository users;
    private final PetRepository pets;
    private final MediaService media;
    private final Clock clock;

    public UserService(UserRepository users, PetRepository pets, MediaService media, Clock clock) {
        this.users = users;
        this.pets = pets;
        this.media = media;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public UserDtos.MeResponse me(UUID userId) {
        return toMe(require(userId));
    }

    @Transactional
    public UserDtos.MeResponse update(UUID userId, UserDtos.UpdateMeRequest request) {
        User user = require(userId);
        Instant now = clock.instant();
        if (request.username() != null) {
            String username = request.username().toLowerCase(Locale.ROOT);
            if (!username.equals(user.getUsername())) {
                if (users.existsByUsername(username)) {
                    throw ApiException.conflict("username_taken", "Ese nombre de usuario ya está en uso.");
                }
                user.setUsername(username, now);
            }
        }
        if (request.displayName() != null) {
            String name = request.displayName().trim();
            if (name.isEmpty()) {
                throw ApiException.badRequest("validation_failed", "El nombre visible no puede estar vacío.");
            }
            user.setDisplayName(name, now);
        }
        if (request.timeZone() != null) {
            if (!TimeZones.isValid(request.timeZone())) {
                throw ApiException.badRequest("invalid_time_zone", "Zona horaria no válida.");
            }
            user.setTimeZone(request.timeZone(), now);
        }
        if (request.avatarMediaId() != null && !request.avatarMediaId().equals(user.getAvatarMediaId())) {
            media.requireOwned(request.avatarMediaId(), userId, MediaAsset.Purpose.USER_AVATAR);
            user.setAvatarMediaId(request.avatarMediaId(), now);
        }
        users.flush();
        return toMe(user);
    }

    private User require(UUID userId) {
        return users.findById(userId)
                .orElseThrow(() -> ApiException.unauthorized("unauthorized", "Inicia sesión para continuar."));
    }

    private UserDtos.MeResponse toMe(User u) {
        return new UserDtos.MeResponse(u.getId(), u.getEmail(), u.getUsername(), u.getDisplayName(),
                MediaUrls.thumbnail(u.getAvatarMediaId()), u.getTimeZone(), u.isProfileCompleted(),
                pets.countByOwnerId(u.getId()), u.getCreatedAt());
    }
}
