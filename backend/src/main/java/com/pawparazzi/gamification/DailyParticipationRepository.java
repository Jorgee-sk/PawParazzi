package com.pawparazzi.gamification;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DailyParticipationRepository extends JpaRepository<DailyParticipation, UUID> {

    Optional<DailyParticipation> findByUserIdAndLocalDate(UUID userId, LocalDate localDate);

    boolean existsByUserIdAndLocalDate(UUID userId, LocalDate localDate);
}
