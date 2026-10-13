package com.pawparazzi.safety;

import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.friendships.FriendRequest;
import com.pawparazzi.friendships.FriendRequestRepository;
import com.pawparazzi.friendships.Friendship;
import com.pawparazzi.friendships.FriendshipRepository;
import com.pawparazzi.users.UserDirectory;
import com.pawparazzi.users.UserDtos.UserSummary;
import com.pawparazzi.users.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Bloquear a una persona:
 * <ul>
 *   <li>rompe la amistad si existía, así que cada una deja de ver el contenido de la otra
 *       (la visibilidad es solo entre amistades);</li>
 *   <li>cierra las solicitudes de amistad pendientes entre ambas;</li>
 *   <li>impide nuevas solicitudes en cualquier sentido (la otra persona recibe "usuario no
 *       encontrado": no se le revela que está bloqueada);</li>
 *   <li>oculta sus comentarios en publicaciones de terceros.</li>
 * </ul>
 * Desbloquear no restaura la amistad: hay que volver a enviar una solicitud.
 */
@Service
public class BlockService {

    public record BlockedView(UserSummary user, Instant since) {
    }

    private final BlockRepository blocks;
    private final FriendshipRepository friendships;
    private final FriendRequestRepository requests;
    private final UserRepository users;
    private final UserDirectory directory;
    private final Clock clock;

    public BlockService(BlockRepository blocks, FriendshipRepository friendships, FriendRequestRepository requests,
                        UserRepository users, UserDirectory directory, Clock clock) {
        this.blocks = blocks;
        this.friendships = friendships;
        this.requests = requests;
        this.users = users;
        this.directory = directory;
        this.clock = clock;
    }

    @Transactional
    public void block(UUID blockerId, UUID targetId) {
        if (blockerId.equals(targetId)) {
            throw ApiException.badRequest("self_block", "No puedes bloquear tu propia cuenta.");
        }
        if (!users.existsById(targetId)) {
            throw ApiException.notFound("user_not_found", "No encontramos a esa persona.");
        }
        if (blocks.findByBlockerIdAndBlockedId(blockerId, targetId).isPresent()) {
            return; // idempotente
        }
        Instant now = clock.instant();
        blocks.save(new Block(blockerId, targetId, now));

        UUID[] pair = Friendship.ordered(blockerId, targetId);
        friendships.findByUserLowIdAndUserHighId(pair[0], pair[1]).ifPresent(friendships::delete);
        requests.findFirstByRequesterIdAndAddresseeIdAndStatus(targetId, blockerId, FriendRequest.Status.PENDING)
                .ifPresent(r -> r.resolve(FriendRequest.Status.REJECTED, now));
        requests.findFirstByRequesterIdAndAddresseeIdAndStatus(blockerId, targetId, FriendRequest.Status.PENDING)
                .ifPresent(r -> r.resolve(FriendRequest.Status.CANCELLED, now));
    }

    @Transactional
    public void unblock(UUID blockerId, UUID targetId) {
        Block block = blocks.findByBlockerIdAndBlockedId(blockerId, targetId)
                .orElseThrow(() -> ApiException.notFound("block_not_found", "Esa persona no está bloqueada."));
        blocks.delete(block);
    }

    @Transactional(readOnly = true)
    public List<BlockedView> listBlocked(UUID blockerId) {
        List<Block> mine = blocks.findAllByBlockerIdOrderByCreatedAtDesc(blockerId);
        Map<UUID, UserSummary> people = directory.summaries(mine.stream().map(Block::getBlockedId).toList());
        return mine.stream()
                .map(b -> {
                    UserSummary user = people.get(b.getBlockedId());
                    return user == null ? null : new BlockedView(user, b.getCreatedAt());
                })
                .filter(Objects::nonNull)
                .toList();
    }
}
