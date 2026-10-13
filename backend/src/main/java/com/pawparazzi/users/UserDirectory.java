package com.pawparazzi.users;

import com.pawparazzi.media.MediaUrls;
import java.util.Collection;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Lectura de resúmenes públicos de personas en lote (evita N+1 en feed y amistades). */
@Component
public class UserDirectory {

    private final UserRepository users;

    public UserDirectory(UserRepository users) {
        this.users = users;
    }

    @Transactional(readOnly = true)
    public Map<UUID, UserDtos.UserSummary> summaries(Collection<UUID> ids) {
        if (ids.isEmpty()) {
            return Map.of();
        }
        return users.findAllById(ids).stream()
                .map(UserDirectory::toSummary)
                .collect(Collectors.toMap(UserDtos.UserSummary::id, Function.identity()));
    }

    public static UserDtos.UserSummary toSummary(User u) {
        return new UserDtos.UserSummary(u.getId(), u.getUsername(), u.getDisplayName(),
                MediaUrls.thumbnail(u.getAvatarMediaId()));
    }
}
