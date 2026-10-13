package com.pawparazzi.users;

import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.media.storage.StorageService;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Eliminación definitiva de la cuenta, confirmada con la contraseña.
 *
 * <p>Se borra todo lo que pertenece a la persona: sesiones, perfil, mascotas, publicaciones (con sus
 * comentarios y cariños), sus comentarios y cariños en publicaciones ajenas, amistades y solicitudes,
 * racha, bloqueos y las imágenes guardadas (filas y ficheros). Los reportes que hizo se conservan sin
 * autor, y los reportes sobre su contenido se conservan sin referencia a la persona, para no perder
 * el historial de moderación.</p>
 *
 * <p>Las filas se borran en una transacción; los ficheros, después de confirmarla. Si el borrado de
 * algún fichero falla, queda registrado en el log para limpiarlo a mano: la cuenta ya no existe.</p>
 */
@Service
public class AccountDeletionService {

    private static final Logger log = LoggerFactory.getLogger(AccountDeletionService.class);

    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbc;
    private final StorageService storage;

    public AccountDeletionService(UserRepository users, PasswordEncoder passwordEncoder, JdbcTemplate jdbc,
                                  StorageService storage) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jdbc = jdbc;
        this.storage = storage;
    }

    @Transactional
    public void deleteAccount(UUID userId, String password) {
        User user = users.findById(userId)
                .orElseThrow(() -> ApiException.unauthorized("unauthorized", "Inicia sesión para continuar."));
        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            throw ApiException.forbidden("wrong_password", "La contraseña no es correcta.");
        }

        List<String> files = new ArrayList<>();
        jdbc.query("select storage_key, thumbnail_key from media_assets where owner_id = ?", rs -> {
            files.add(rs.getString(1));
            files.add(rs.getString(2));
        }, userId);

        // Las publicaciones van primero porque referencian sus imágenes sin borrado en cascada.
        // El resto (mascotas, comentarios, cariños, amistades, sesiones, imágenes...) cae en cascada con la persona.
        jdbc.update("delete from posts where author_id = ?", userId);
        jdbc.update("delete from users where id = ?", userId);

        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                for (String key : files) {
                    try {
                        storage.delete(key);
                    } catch (RuntimeException e) {
                        log.error("Cuenta {} eliminada, pero no se pudo borrar el fichero {}", userId, key, e);
                    }
                }
            }
        });
        log.info("Cuenta {} eliminada ({} ficheros)", userId, files.size());
    }
}
