# Arquitectura de PawParazzi

## Visión general

```
mobile/   Flutter (Riverpod 3, GoRouter, Dio)  ──HTTP/JSON + Bearer JWT──►  backend/  Spring Boot 3.5 (Java 21)
                                                                              │
                                                     PostgreSQL (Flyway) ◄────┤  metadatos
                                      Almacenamiento local o S3 (SeaweedFS) ◄────┘  bytes de imágenes
```

Monolito modular: un único despliegue con límites claros por paquete. Sin colas, Redis ni microservicios.

**Contenedores**: el entorno local usa **Podman** (sin demonio, rootless) con `compose.yaml` en formato
Compose Spec estándar, portable a cualquier motor compatible. Servicios: PostgreSQL 17, SeaweedFS
(gateway S3) y el servicio propio de revisión de fotos (`moderation/`). El backend solo usa operaciones básicas del API S3 (`put/get/delete`, `head/createBucket`),
así que en producción puede apuntar a cualquier proveedor S3 sin cambios de código.

## Backend (`backend/src/main/java/com/pawparazzi`)

| Módulo | Responsabilidad |
|---|---|
| `common` | Configuración, seguridad (JWT HS256, BCrypt, CORS, rate limit de auth), errores uniformes, `@CurrentUserId` |
| `identity` | Registro, login, refresh con rotación, logout |
| `users` | `/users/me`, resúmenes públicos en lote (`UserDirectory`) |
| `pets` | CRUD de mascotas, visibilidad (propia o amistad) |
| `media` | Subida validada, re-codificación sin EXIF/GPS, miniaturas, `StorageService` intercambiable, acceso controlado |
| `moments` | Publicaciones PawMoment/Caza libre, ventana diaria, feed de amigos, publicaciones por mascota |
| `gamification` | PawStreak y participaciones diarias |
| `friendships` | Solicitudes y amistades |
| `reactions` | Cariños (una por persona y publicación) |
| `comments` | Comentarios de publicaciones visibles, paginados |
| `media.moderation` | Revisión automática de imágenes con proveedor intercambiable (`ImageModerator`) |

Los controladores solo traducen HTTP; la lógica vive en servicios transaccionales. Las entidades JPA
nunca se exponen: se devuelven DTO (`*Dtos`). Las referencias entre módulos son por UUID (sin
relaciones JPA cruzadas) y las vistas se componen en lote (`PostAssembler`) para evitar N+1.

### Modelo de datos (migraciones `V1`–`V6`)

`users`, `refresh_tokens`, `media_assets`, `pets`, `pet_tags`, `posts`, `post_pets`, `post_tags`,
`daily_participations`, `paw_streaks`, `friend_requests`, `friendships`, `reactions`, `comments`.
Las tablas de fase 2 (misiones, grupos, recuerdos, logros…) se crearán con su funcionalidad.

### Reglas de negocio clave

- **Visibilidad (servidor)**: una persona ve contenido propio y de amistades aceptadas. Lo ajeno
  responde **404** (no se revela su existencia). Se aplica en feed, publicaciones, mascotas, imágenes y reacciones.
- **Ventana PawMoment**: hora de inicio determinista por fecha entre `earliest-start` y `latest-start`
  (hora local de la persona), duración `window-duration`. Es informativa: publicar antes o después se
  permite, cuenta para la racha y se marca `onTime=false`.
- **Racha (PawStreak)**: solo cuentan los PawMoment; una participación por persona y **día natural local**
  (zona IANA guardada en `users.time_zone`, enviada por el móvil al registrarse). Día consecutivo → +1;
  hueco → vuelve a 1; la mejor racha se conserva. Un día anterior al último (cambio de zona hacia atrás)
  suma días participados sin alterar la racha. La racha visible es 0 si no se participó ni ayer ni hoy.
  Borrar la publicación no borra la participación. Un segundo PawMoment el mismo día responde
  `409 already_participated` (se puede publicar como Caza libre).
- **Idempotencia**: cada publicación lleva `clientRequestId` (único por autor). Un reintento devuelve la
  publicación existente (`200`, `replayed=true`) sin contar racha. Las participaciones se serializan con
  bloqueo de fila sobre `paw_streaks` + restricción única `(user_id, local_date)`.
- **Imágenes**: tipo detectado por firma binaria (JPEG/PNG), límite de 10 MB y 50 MP, orientación EXIF
  aplicada, re-codificación JPEG sin metadatos (elimina EXIF/GPS), versión ≤2048 px y miniatura ≤480 px.
  Se sirven por `/api/v1/media/{id}` con autorización (propietaria o amistad).
- **Revisión de fotos** (`pawparazzi.moderation.provider`): `none` o `local`. Con `local`, el backend envía la
  miniatura por HTTP al servicio `moderation/` (Python, FastAPI, ONNX Runtime, modelo CLIP ViT-B/32), que
  devuelve tres puntuaciones de 0 a 1: `animal`, `violence`, `sexual`. El servicio solo puntúa; los umbrales y
  la decisión están en el backend (`LocalImageModerator`, `ModerationPolicy`): primero seguridad, después
  "¿hay un animal?" (no exigido en avatares de persona). Una imagen rechazada no se guarda y responde
  `422 image_rejected` con el motivo. Si el servicio falla, `on-error` decide: `allow` (por defecto; la imagen
  se guarda como `UNCHECKED`) o `reject` (`503 moderation_unavailable`). No se infieren emociones ni salud.
- **Comentarios**: los lee y escribe quien ve la publicación. Borra quien lo escribió o la autora de la publicación.
- **Sesión**: access token JWT de 15 min; refresh token opaco de 30 días guardado como hash SHA-256 y
  rotado en cada uso. Reutilizar un refresh ya rotado revoca todas las sesiones.

### API v1 (OpenAPI en `/v3/api-docs`, Swagger UI en `/swagger-ui.html`)

| Método y ruta | Descripción |
|---|---|
| `POST /auth/register · /auth/login · /auth/refresh · /auth/logout` | Sesión |
| `GET·PATCH /users/me` | Perfil propio |
| `GET·POST /pets`, `GET·PUT·DELETE /pets/{id}`, `GET /users/{id}/pets` | Mascotas |
| `POST /media` (multipart, `purpose`), `GET /media/{id}?variant=thumb` | Imágenes |
| `POST /posts`, `GET·PATCH·DELETE /posts/{id}` | Publicaciones |
| `GET /feed/friends?cursor&limit`, `GET /pets/{id}/posts` | Feeds paginados por cursor |
| `GET /moments/today` | Ventana y participación de hoy |
| `GET /gamification/streak` | PawStreak |
| `POST·GET /friend-requests`, `POST /friend-requests/{id}/accept·reject`, `DELETE /friend-requests/{id}`, `GET /friends`, `DELETE /friends/{id}` | Amistades |
| `PUT·DELETE /posts/{id}/reactions/me` | Cariños |
| `GET·POST /posts/{id}/comments`, `DELETE /comments/{id}` | Comentarios |

Errores: `{code, message, timestamp, fieldErrors?}` con códigos estables; nunca trazas.

## Móvil (`mobile/lib`)

```
core/      config · theme (tokens Figma) · network (ApiClient, ApiException, MediaCache) · auth (sesión, tokens)
           router (GoRouter + redirect por sesión) · widgets (componentes del sistema de diseño)
features/  auth · profile · pets · media · moments · feed · gamification · friends · shell
           cada una con data/ (modelos + repositorios) y presentation/ (pantallas + controladores)
```

- **Estado**: Riverpod 3 (`Notifier`/`AsyncNotifier`/`FutureProvider`). Reintentos automáticos desactivados:
  los errores se muestran y la persona decide reintentar.
- **Navegación**: `redirectFor` (función pura y testeada) lleva de sesión → perfil → primera mascota → Inicio.
  `StatefulShellRoute` para las 5 pestañas; captura y publicación a pantalla completa.
- **Red**: `ApiClient` añade el token, renueva la sesión una sola vez ante 401 (peticiones concurrentes
  comparten la renovación) y reintenta. Las imágenes privadas se descargan con el cliente autenticado
  y se cachean en memoria (LRU).
- **Publicación**: `PostPublisher` conserva `clientRequestId` y la imagen subida entre reintentos.

## Pruebas

- Backend (JUnit 5, MockMvc, H2 en modo PostgreSQL con las mismas migraciones): autenticación, rotación
  de tokens, validación, flujo social completo, visibilidad, idempotencia, racha, paginación, subida.
- Flutter: redirecciones del router, refresh de sesión, idempotencia del publicador, widgets y estados
  de carga/vacío/error.
