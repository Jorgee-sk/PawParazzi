package com.pawparazzi.gamification;

import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PawStreakRepository extends JpaRepository<PawStreak, UUID> {

    /** Bloqueo de fila: serializa las participaciones concurrentes de una misma persona. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from PawStreak s where s.userId = :userId")
    Optional<PawStreak> findForUpdate(@Param("userId") UUID userId);
}
