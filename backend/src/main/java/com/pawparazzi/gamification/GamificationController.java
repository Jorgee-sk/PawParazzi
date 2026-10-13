package com.pawparazzi.gamification;

import com.pawparazzi.common.TimeZones;
import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.common.security.CurrentUserId;
import com.pawparazzi.users.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/gamification")
@Tag(name = "Gamificación")
public class GamificationController {

    private final StreakService streakService;
    private final UserRepository users;

    public GamificationController(StreakService streakService, UserRepository users) {
        this.streakService = streakService;
        this.users = users;
    }

    @Operation(summary = "PawStreak de la persona autenticada (racha actual, mejor, días y próximo hito)")
    @GetMapping("/streak")
    public StreakService.StreakView streak(@CurrentUserId UUID userId) {
        var user = users.findById(userId)
                .orElseThrow(() -> ApiException.unauthorized("unauthorized", "Inicia sesión para continuar."));
        return streakService.view(userId, TimeZones.parseOrUtc(user.getTimeZone()));
    }
}
