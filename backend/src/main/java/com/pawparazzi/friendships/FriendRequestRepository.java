package com.pawparazzi.friendships;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FriendRequestRepository extends JpaRepository<FriendRequest, UUID> {

    Optional<FriendRequest> findFirstByRequesterIdAndAddresseeIdAndStatus(UUID requesterId, UUID addresseeId,
                                                                          FriendRequest.Status status);

    List<FriendRequest> findAllByAddresseeIdAndStatusOrderByCreatedAtDesc(UUID addresseeId, FriendRequest.Status status);

    List<FriendRequest> findAllByRequesterIdAndStatusOrderByCreatedAtDesc(UUID requesterId, FriendRequest.Status status);
}
