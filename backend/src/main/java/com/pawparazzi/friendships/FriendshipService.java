package com.pawparazzi.friendships;

import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.safety.BlockRepository;
import com.pawparazzi.users.User;
import com.pawparazzi.users.UserDirectory;
import com.pawparazzi.users.UserDtos.UserSummary;
import com.pawparazzi.users.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reglas de amistad:
 * <ul>
 *   <li>Las solicitudes se envían por nombre de usuario.</li>
 *   <li>Si ya existe una solicitud pendiente en sentido contrario, enviar otra la acepta.</li>
 *   <li>Reenviar una solicitud pendiente es idempotente (devuelve la existente).</li>
 *   <li>Solo la persona destinataria acepta o rechaza; solo quien la envió la cancela.</li>
 *   <li>Si hay un bloqueo entre ambas personas (en cualquier sentido) no se pueden enviar solicitudes.</li>
 * </ul>
 */
@Service
public class FriendshipService {

    public record FriendRequestView(UUID id, UserSummary requester, UserSummary addressee, String status,
                                    Instant createdAt) {
    }

    public record FriendView(UserSummary user, Instant since) {
    }

    private final FriendshipRepository friendships;
    private final FriendRequestRepository requests;
    private final UserRepository users;
    private final UserDirectory directory;
    private final BlockRepository blocks;
    private final Clock clock;

    public FriendshipService(FriendshipRepository friendships, FriendRequestRepository requests,
                             UserRepository users, UserDirectory directory, BlockRepository blocks, Clock clock) {
        this.friendships = friendships;
        this.requests = requests;
        this.users = users;
        this.directory = directory;
        this.blocks = blocks;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public boolean areFriends(UUID a, UUID b) {
        if (a.equals(b)) {
            return false;
        }
        UUID[] pair = Friendship.ordered(a, b);
        return friendships.existsByUserLowIdAndUserHighId(pair[0], pair[1]);
    }

    /** Persona propia o amistad: puede ver su contenido. */
    @Transactional(readOnly = true)
    public boolean canSee(UUID viewerId, UUID ownerId) {
        return viewerId.equals(ownerId) || areFriends(viewerId, ownerId);
    }

    @Transactional
    public FriendRequestView sendRequest(UUID requesterId, String username) {
        String normalized = username == null ? "" : username.trim().toLowerCase(Locale.ROOT).replaceFirst("^@", "");
        User addressee = users.findByUsername(normalized)
                .orElseThrow(() -> ApiException.notFound("user_not_found", "No encontramos a nadie con ese usuario."));
        UUID addresseeId = addressee.getId();
        if (addresseeId.equals(requesterId)) {
            throw ApiException.badRequest("self_request", "No puedes enviarte una solicitud a tu propia cuenta.");
        }
        if (blocks.existsBetween(requesterId, addresseeId)) {
            // Misma respuesta que si no existiera: no se revela quién ha bloqueado a quién.
            throw ApiException.notFound("user_not_found", "No encontramos a nadie con ese usuario.");
        }
        if (areFriends(requesterId, addresseeId)) {
            throw ApiException.conflict("already_friends", "Ya sois amigos.");
        }
        Instant now = clock.instant();
        var reverse = requests.findFirstByRequesterIdAndAddresseeIdAndStatus(addresseeId, requesterId,
                FriendRequest.Status.PENDING);
        if (reverse.isPresent()) {
            FriendRequest request = reverse.get();
            request.resolve(FriendRequest.Status.ACCEPTED, now);
            friendships.save(new Friendship(requesterId, addresseeId, now));
            return view(request);
        }
        FriendRequest request = requests
                .findFirstByRequesterIdAndAddresseeIdAndStatus(requesterId, addresseeId, FriendRequest.Status.PENDING)
                .orElseGet(() -> requests.save(new FriendRequest(requesterId, addresseeId, now)));
        return view(request);
    }

    @Transactional
    public FriendRequestView accept(UUID userId, UUID requestId) {
        FriendRequest request = pendingAddressedTo(userId, requestId);
        Instant now = clock.instant();
        request.resolve(FriendRequest.Status.ACCEPTED, now);
        if (!areFriends(request.getRequesterId(), request.getAddresseeId())) {
            friendships.save(new Friendship(request.getRequesterId(), request.getAddresseeId(), now));
        }
        return view(request);
    }

    @Transactional
    public FriendRequestView reject(UUID userId, UUID requestId) {
        FriendRequest request = pendingAddressedTo(userId, requestId);
        request.resolve(FriendRequest.Status.REJECTED, clock.instant());
        return view(request);
    }

    @Transactional
    public void cancel(UUID userId, UUID requestId) {
        FriendRequest request = requests.findById(requestId)
                .filter(r -> r.getRequesterId().equals(userId) && r.getStatus() == FriendRequest.Status.PENDING)
                .orElseThrow(FriendshipService::requestNotFound);
        request.resolve(FriendRequest.Status.CANCELLED, clock.instant());
    }

    @Transactional
    public void removeFriend(UUID userId, UUID friendId) {
        UUID[] pair = Friendship.ordered(userId, friendId);
        Friendship friendship = friendships.findByUserLowIdAndUserHighId(pair[0], pair[1])
                .orElseThrow(() -> ApiException.notFound("friend_not_found", "Esa persona no está entre tus amistades."));
        friendships.delete(friendship);
    }

    @Transactional(readOnly = true)
    public List<FriendView> listFriends(UUID userId) {
        List<Friendship> all = friendships.findAllOf(userId);
        Map<UUID, UserSummary> people = directory.summaries(all.stream().map(f -> f.otherThan(userId)).toList());
        List<FriendView> result = new ArrayList<>();
        for (Friendship f : all) {
            UserSummary other = people.get(f.otherThan(userId));
            if (other != null) {
                result.add(new FriendView(other, f.getCreatedAt()));
            }
        }
        return result;
    }

    @Transactional(readOnly = true)
    public List<FriendRequestView> incoming(UUID userId) {
        return views(requests.findAllByAddresseeIdAndStatusOrderByCreatedAtDesc(userId, FriendRequest.Status.PENDING));
    }

    @Transactional(readOnly = true)
    public List<FriendRequestView> outgoing(UUID userId) {
        return views(requests.findAllByRequesterIdAndStatusOrderByCreatedAtDesc(userId, FriendRequest.Status.PENDING));
    }

    private FriendRequest pendingAddressedTo(UUID userId, UUID requestId) {
        return requests.findById(requestId)
                .filter(r -> r.getAddresseeId().equals(userId) && r.getStatus() == FriendRequest.Status.PENDING)
                .orElseThrow(FriendshipService::requestNotFound);
    }

    private List<FriendRequestView> views(List<FriendRequest> list) {
        List<UUID> ids = new ArrayList<>();
        list.forEach(r -> {
            ids.add(r.getRequesterId());
            ids.add(r.getAddresseeId());
        });
        Map<UUID, UserSummary> people = directory.summaries(ids);
        return list.stream().map(r -> new FriendRequestView(r.getId(), people.get(r.getRequesterId()),
                people.get(r.getAddresseeId()), r.getStatus().name(), r.getCreatedAt())).toList();
    }

    private FriendRequestView view(FriendRequest r) {
        return views(List.of(r)).getFirst();
    }

    private static ApiException requestNotFound() {
        return ApiException.notFound("request_not_found", "Solicitud no encontrada.");
    }
}
