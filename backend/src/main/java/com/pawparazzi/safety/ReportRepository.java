package com.pawparazzi.safety;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReportRepository extends JpaRepository<Report, UUID> {

    Optional<Report> findByReporterIdAndTargetTypeAndTargetId(UUID reporterId, Report.TargetType targetType,
                                                              UUID targetId);
}
