# Roadmap

Leyenda: ✅ hecho y verificado · 🟡 hecho pero sin verificar en el entorno real · ⬜ pendiente

## Fase 0 — Base técnica

- ✅ Monorepo `backend/` (Spring Boot 3.5.16, Java 21, Maven wrapper) + `mobile/` (Flutter 3.44)
- ✅ Flyway con migraciones versionadas por funcionalidad
- ✅ Errores uniformes, seguridad JWT, CORS, OpenAPI
- ✅ Almacenamiento de imágenes intercambiable; proveedor local verificado
- ✅ Contenedores con **Podman** en lugar de Docker: `compose.yaml` (Compose Spec) con imágenes de nombre
  completo y versiones fijadas (PostgreSQL 17.11, SeaweedFS 4.48). Ejecutado con Podman 6.0.2 sobre WSL
- ✅ MinIO sustituido por **SeaweedFS** (Apache 2.0): las imágenes comunitarias de MinIO ya no se publican
  en Docker Hub ni Quay (comprobado el 12/10/2026)
- ✅ Adaptador S3 verificado contra SeaweedFS (`S3StorageServiceIT`); el backend crea el bucket si falta
- ✅ Migraciones Flyway V1–V4 aplicadas en PostgreSQL 17.11 real y flujo completo de la API sobre
  PostgreSQL + SeaweedFS
- ✅ `scripts/dev-services.ps1`: arranca los servicios y corrige el reenvío de puertos en Windows
- ⬜ Los problemas de la máquina de Podman en Windows (cgroups y puertos, ver README) son del entorno, no del
  proyecto: revisar si desaparecen al actualizar Podman/WSL y, si es así, simplificar el script
- ✅ `.env.example`, README, ARCHITECTURE, sistema de diseño documentado desde Figma

## Fase 1 — MVP social

- ✅ Registro, login, refresh con rotación, logout (backend + Flutter)
- ✅ Onboarding: perfil (username, nombre visible) → primera mascota
- ✅ Mascotas: crear, editar, eliminar, perfil con su archivo de fotos
- ✅ Subida segura: firma binaria, límites, EXIF/GPS eliminado, miniaturas, acceso solo propietaria/amistades
- ✅ PawMoment con ventana informativa que nunca bloquea; indicador «a tiempo / fuera de la ventana»
- ✅ PawParazzi Mode (Caza libre) con categorías manuales
- ✅ Publicación idempotente con reintento que conserva foto, mascotas y texto
- ✅ PawStreak básico (servidor, idempotente, por día local)
- ✅ Amistades: enviar por username, aceptar, rechazar, cancelar, eliminar
- ✅ Feed de amigos paginado por cursor con estados de carga, vacío y error
- ✅ Reacciones (cariños) idempotentes con actualización optimista
- ✅ Eliminar publicaciones propias
- ✅ Comentarios: crear, listar paginado, borrar los propios (y cualquiera en publicaciones propias), contador en `PostCard`
- ✅ Editar perfil desde la app: foto, nombre visible y nombre de usuario
- ✅ Corregido: las imágenes cargadas por red no llegaban a pintarse (`MediaCache` se quedaba esperando)
- ✅ En pantallas anchas (web/tablet) el contenido se centra con ancho de móvil
- ✅ Revisión automática de fotos con un modelo abierto en contenedor propio (CLIP ViT-B/32, sin coste por foto):
  rechaza fotos sin animal real y con violencia o contenido sexual. Verificado de extremo a extremo con Podman y
  con una muestra de 56 fotos de Wikimedia Commons (ver `moderation/README.md`)
- ✅ Renombrado: «Cazar» → «Capturar», «Caza libre» → «Foto libre»
- ✅ Reportar publicaciones, comentarios y personas (sin duplicados; los reportes sobreviven al borrado del contenido)
- ✅ Bloquear y desbloquear: rompe la amistad, impide nuevas solicitudes y oculta comentarios
- ✅ Eliminar la cuenta y todos sus datos (filas y ficheros), con contraseña y doble confirmación
- ✅ Fotos con enlaces firmados que caducan: la app las descarga del almacenamiento sin pasar por el backend
- ✅ Límite de fotos procesándose a la vez al subir (`503 server_busy` y reintento en la app)
- ⬜ **Siguiente bloque**: verificación de email y recuperación de contraseña
- ⬜ Panel o herramienta para revisar reportes (hoy se revisan con SQL, ver README) y avisar a quien reportó
- ⬜ Revisión de fotos: evaluar con un conjunto etiquetado a mano más grande (sobre todo violencia y contenido
  sexual, probados con pocos ejemplos); valorar un clasificador específico de desnudos si CLIP se queda corto;
  revisar también el texto de publicaciones y comentarios
- ⬜ Editar publicación desde Flutter (el endpoint `PATCH /posts/{id}` ya existe)
- ⬜ Visor de cámara integrado (hoy se usa la cámara del sistema vía `image_picker`)
- ⬜ Recuperar foto tras cierre del proceso en Android (`retrieveLostData`) y borradores persistentes
- ⬜ Notificación diaria configurable de PawMoment (FCM) y ajustes
- ⬜ Test de integración Flutter contra backend real; pruebas en dispositivos iOS/Android

## Preparación para producción

- ✅ Control de versiones (git) con ramas por funcionalidad
- ✅ Integración continua en GitHub Actions (backend sobre PostgreSQL y SeaweedFS, Flutter, Python), en verde en
  `github.com/Jorgee-sk/PawParazzi`
- ✅ Fotos servidas con enlaces firmados directamente desde el almacenamiento (verificado con SeaweedFS y desde
  un navegador en otro origen)
- ✅ Límite de subidas procesándose a la vez; el procesado ya no retiene una conexión a la base de datos
- ⬜ CDN delante del almacenamiento (los enlaces prefirmados cambian en cada respuesta, así que una CDN no los
  cachea tal cual: harán falta cookies o URLs firmadas de la propia CDN)
- ⬜ Cola de procesamiento de imágenes si el límite simultáneo se queda corto
- ⬜ Almacenamiento con réplicas o gestionado (SeaweedFS de un nodo es solo para desarrollo)
- ⬜ Límites de frecuencia compartidos entre instancias y también para subidas, comentarios y reportes
- ⬜ Limpieza programada de sesiones caducadas e imágenes sin publicar
- ⬜ Verificación de email y recuperación de contraseña
- ⬜ Despliegue: HTTPS, perfil de producción (documentación de la API cerrada, orígenes permitidos), copias de
  seguridad, monitorización y alertas
- ⬜ Prueba de carga

## Fase 2 — Gamificación y comunidad

⬜ Paw Hunt (misión semanal configurable desde backend) · PawPoints con transacciones · insignias y pantalla de
logros · marcos cosméticos · PawSquads con feed privado y racha compartida · recuerdos mensuales ·
calendario de participación · notificaciones.

## Fase 3 — IA y evolución

⬜ Analizador intercambiable · etiquetas sugeridas editables · archivo de personalidad · resúmenes enriquecidos.

## Fuera del MVP

Muro público de avistamientos, votaciones, rankings, mensajería privada, tienda compleja.
