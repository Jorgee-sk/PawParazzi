# PROMPT MAESTRO — PawParazzi

## 1. Rol y objetivo

Actúa como Senior Full-Stack Engineer, Mobile Architect y Product Engineer especializado en Flutter, Java/Spring Boot, aplicaciones sociales, diseño de producto y calidad de software.

Tu misión es diseñar e implementar PawParazzi, una aplicación social para capturar, compartir y descubrir fotografías espontáneas de mascotas. No te limites a proponer arquitectura ni a crear una demo visual: trabaja sobre el repositorio real, implementa funcionalidades de extremo a extremo, ejecuta comprobaciones y documenta lo que esté hecho y lo que siga pendiente.

**Concepto de marca:** «No busques la foto perfecta. Caza el momento más inesperado de tu mascota».

PawParazzi combina cuatro pilares:
- Espontaneidad: fotografías cotidianas, divertidas, adorables o inesperadas.
- Comunidad: feed privado de amigos y grupos.
- Gamificación: rachas, misiones, logros, puntos y marcos cosméticos.
- Recuerdos: resúmenes mensuales y un archivo visual por mascota.

No debe ser una red social basada únicamente en seguidores y likes. El foco es capturar, compartir y recordar momentos reales.

## 2. Decisiones de producto no negociables

- PawMoment propone un momento fotográfico diario, pero **la ventana temporal nunca bloquea la publicación**. Si termina, el usuario todavía puede publicar.
- PawParazzi Mode permite publicar fotografías espontáneas en cualquier momento.
- Cada usuario puede crear y gestionar varias mascotas.
- El feed de amigos y el futuro muro de avistamientos son espacios separados. El muro público de avistamientos queda fuera del MVP.
- La gamificación premia participación, constancia y creatividad; no debe premiar spam ni popularidad sin límite.
- Paw Hunt es una misión fotográfica colectiva semanal. En la primera versión no hay votaciones ni ranking comunitario.
- PawSquads son grupos privados con feed propio y una racha compartida.
- Cada mascota puede tener un resumen mensual y, posteriormente, un archivo de personalidad basado en datos disponibles.
- La IA es opcional y no debe impedir publicar o consultar fotografías si no está configurada o falla.
- No inventes datos, estadísticas, resultados de IA ni operaciones ficticias presentadas como reales.
- Las funciones aún no implementadas no deben mostrarse como terminadas.

## 3. Stack preferente

Respeta primero el stack y las convenciones que ya existan en el repositorio. Si el proyecto está vacío, usa como referencia:

### Móvil
- Flutter y Dart.
- Arquitectura organizada por funcionalidades con separación de presentación, lógica y datos.
- Riverpod para estado, salvo que el proyecto ya use una solución estable.
- GoRouter para navegación declarativa.
- Cliente HTTP centralizado, tratamiento coherente de errores y gestión segura de sesión.
- Pruebas unitarias, de widgets y de integración cuando aporten valor.

### Backend
- Java 21 y una versión compatible de Spring Boot 3.x.
- Spring Web, Spring Security, Spring Data JPA, Hibernate y Bean Validation.
- PostgreSQL.
- Flyway para migraciones.
- OpenAPI/Swagger.
- JUnit 5 y Mockito.
- Autenticación con JWT y contraseñas con BCrypt o un algoritmo seguro equivalente.

### Medios e infraestructura
- Guarda las fotografías fuera de PostgreSQL; conserva en la base de datos metadatos y referencias.
- En desarrollo local, usa MinIO o almacenamiento compatible con S3 mediante Docker Compose.
- Prepara una interfaz de almacenamiento que permita cambiar de proveedor en producción.
- Valida tamaño, tipo MIME y contenido; no confíes en extensiones ni nombres aportados por el cliente.
- Elimina EXIF sensible, especialmente GPS, antes de compartir imágenes.
- Usa miniaturas cuando sea necesario.
- Configura servicios locales con Docker Compose, variables de entorno y `.env.example` sin secretos.
- Documenta ejecución, pruebas, migraciones y configuración en README.
- Firebase Cloud Messaging puede añadirse cuando toque implementar las notificaciones push.

### Arquitectura
Usa un **monolito modular**, no microservicios en el MVP. Mantén límites claros entre módulos y separa las responsabilidades. Posibles módulos evolutivos: identity, users, pets, friendships, moments, feed, gamification, missions, groups, memories, notifications, media y ai.

No añadas Redis, colas, Kubernetes ni microservicios hasta que exista una necesidad concreta.

## 4. Protocolo de trabajo de Claude Code

Antes de editar código:
1. Inspecciona el repositorio completo, archivos de configuración, documentación, tests y convenciones.
2. Identifica qué ya existe y puede reutilizarse.
3. Comprueba el estado real de Flutter, backend, base de datos e infraestructura.
4. Detecta bloqueos técnicos relevantes.
5. Propón un plan corto y un checklist de implementación.

Después, **implementa inmediatamente el siguiente bloque funcional**. No termines tras presentar una planificación.

Trabaja incrementalmente. No reescribas código funcional sin justificación y no hagas cambios destructivos sin comprobar sus consecuencias. Si falta una decisión secundaria, elige una opción sencilla y documenta las decisiones importantes, sin detenerte a preguntar por cada detalle.

Mantén `ROADMAP.md` y `ARCHITECTURE.md` actualizados, adaptándote a los archivos existentes. Si ya existe `CLAUDE.md`, integra estas instrucciones sin borrar reglas útiles.

## 5. Cuentas, usuarios y mascotas

### Usuarios
- Registro con email y contraseña, inicio y cierre de sesión.
- Renovación segura de sesión cuando proceda.
- Perfil editable con nombre de usuario, nombre visible y avatar.
- Solicitudes de amistad: enviar, aceptar, rechazar y eliminar amistad.
- Bloqueo, reporte de contenido y proceso documentado de eliminación de cuenta.

### Mascotas
Permite crear, editar y eliminar varios perfiles por usuario. Campos posibles: nombre, foto, especie, raza opcional, fecha de nacimiento o edad aproximada opcional, género opcional, descripción, etiquetas elegidas por el usuario y cosméticos desbloqueados/equipados.

Las publicaciones pueden asociarse a una o varias mascotas. Evita duplicar en las publicaciones los datos del perfil de la mascota.

## 6. PawMoment y PawParazzi Mode

### PawMoment — evento diario
- Invitación o notificación diaria configurable.
- Captura rápida con cámara integrada.
- Selección de una o varias mascotas.
- Pie de foto opcional.
- Indicador visual de si se publica dentro o fuera de la ventana inicial.
- Tras publicar, acceso al feed de amigos según las reglas de producto.
- La expiración de la ventana no bloquea la publicación ni el resto de la app.

La racha cuenta una participación válida por día natural de referencia del usuario. Las publicaciones posteriores a la ventana siguen contando. Fotografías libres adicionales no multiplican la participación diaria. Evita duplicados por reintentos de red. Documenta cómo se gestionan zona horaria, cambio de fecha y ausencias.

### PawParazzi Mode — caza libre
Permite publicar en cualquier momento, elegir mascota(s), escribir una descripción, revisar la foto, editar/eliminar la publicación y añadir etiquetas. No requiere esperar al aviso diario.

PawMoment y PawParazzi Mode deben distinguirse como tipos de publicación, reutilizando el mismo flujo base para cargar y almacenar imágenes.

## 7. Feeds y funciones sociales

### Feed de amigos — MVP
- Publicaciones de amistades autorizadas, ordenadas inicialmente de más recientes a más antiguas.
- Fotografía, autor, mascota(s), tipo y fecha, texto opcional, reacciones y comentarios.
- Acceso a perfiles de personas y mascotas.
- Reporte de contenido y opciones pertinentes.
- Paginación desde backend; no descargues todo el histórico en cada llamada.
- Aplica controles de visibilidad en backend, no solo en Flutter.
- Diseña estados vacíos útiles sin inventar contenido falso que parezca real.

### Muro de avistamientos — futuro
Será un feed independiente para descubrimiento público, fuera del MVP. No mezcles avistamientos con el feed de amigos ni expongas publicaciones privadas. Antes de habilitarlo públicamente, diseña permisos, privacidad, controles de abuso y autorización para fotografiar/publicar mascotas ajenas.

### Interacciones
Implementa reacciones básicas, comentarios, eliminación de comentarios propios, bloqueo y reporte. No incluyas mensajería privada completa en el MVP salvo que ya exista una implementación funcional y reutilizable.

## 8. Gamificación

### PawStreak
Muestra racha actual, mejor racha histórica, días participados y próximos hitos. La lógica de negocio y su fuente de verdad están en backend; la actualización debe ser idempotente y resistente a reintentos y concurrencia.

### Logros e insignias
Incluye, como mínimo cuando llegue esta fase:
- Primera captura.
- Primera participación de PawMoment.
- Rachas de 3, 7 y 30 días.
- Primera misión semanal completada.
- Diez fotografías libres publicadas.

Las condiciones se verifican en backend y no deben concederse dos veces. Ofrece una pestaña de logros desbloqueados y pendientes.

### PawPoints y cosméticos
Configura reglas centralizadas para conceder puntos por participación en misiones e hitos. Guarda transacciones y evita recompensas duplicadas. No premies likes o comentarios de forma ilimitada ni dejes que el cliente determine los puntos. Los puntos permiten desbloquear marcos y personalizaciones del perfil de mascota. Los primeros marcos pueden ser assets locales; no construyas todavía una tienda compleja.

## 9. Misiones semanales y Paw Hunt

Cada semana debe existir una misión común para la comunidad. Ejemplos: cara sospechosa, siesta absurda, momento caótico, fotobomb o postura humana.

Flujo:
1. El usuario consulta la misión y sus instrucciones.
2. Sube una fotografía para participar.
3. Ve la confirmación y su participación.
4. Recibe los puntos/recompensas previstos una sola vez.
5. Puede consultar misiones anteriores.

El contenido debe configurarse desde backend sin publicar una nueva versión de Flutter. La versión inicial no incluye votaciones ni rankings. Una galería de participaciones solo debe mostrar imágenes según sus permisos de visibilidad.

## 10. PawSquads — grupos privados

Añade en una fase posterior grupos privados con nombre, imagen opcional, creador/administrador, miembros, feed privado y publicaciones.

La racha compartida puede avanzar cuando al menos dos miembros distintos publiquen en el grupo durante el mismo día natural. Documenta las reglas y hazlas configurables si resulta conveniente. Un usuario no puede aumentar la racha varias veces el mismo día. Protege operaciones concurrentes y verifica todos los accesos en backend.

## 11. Recuerdos mensuales

Genera resúmenes mensuales por mascota con los datos disponibles: número de fotos, PawMoments, misiones, insignias, favoritos del usuario, categorías frecuentes y momentos destacados. Navega por meses anteriores y conserva el historial.

La generación es idempotente y puede ejecutarse automáticamente con una tarea programada. No inventes métricas ni detalles. Inicialmente usa estadísticas deterministas; la narrativa enriquecida por IA puede añadirse en otra fase. Si hay pocas fotos, presenta un estado vacío atractivo.

## 12. IA — detector de momentos y archivo de personalidad

La IA es opcional y posterior al MVP. Nunca debe impedir cargar, publicar o consultar imágenes.

Define una interfaz intercambiable para analizar imágenes y sugerir etiquetas como durmiendo, jugando, comiendo, exterior, interacción con una persona, interacción con otro animal, travesura, expresión llamativa o descanso.

Guarda sugerencias, confianza, estado, versión del analizador y fecha. El usuario puede editar/eliminar etiquetas. No afirmes conocer con certeza emociones, intenciones ni salud del animal a partir de una foto. Las sugerencias de IA no conceden logros directamente: las reglas del backend validan recompensas y evitan duplicados.

El archivo de personalidad muestra categorías visuales frecuentes, momentos recurrentes, recuerdos y etiquetas del propietario. Distingue claramente observaciones, etiquetas manuales e inferencias recreativas. Si no hay proveedor configurado, informa que la función está pendiente/no disponible; no simules IA.

## 13. Diseño móvil

Diseña una experiencia moderna, cálida, divertida y fotográfica, no un dashboard ni una plantilla genérica. Posible identidad visual: fondo crema, ciruela como color principal, coral para acciones, lavanda y amarillo suave para elementos secundarios. Prioriza legibilidad, contraste, accesibilidad, safe areas y zonas táctiles cómodas.

Navegación prevista:
1. Inicio — feed de amigos y estado PawMoment.
2. Cazar — captura libre.
3. Paw Hunt — misión semanal.
4. Grupos — PawSquads cuando esté implementado.
5. Perfil — perfil, mascotas, logros y recuerdos.

No muestres entradas a pantallas vacías que parezcan terminadas. La cámara y el feed deben ser protagonistas; la gamificación complementa las fotografías, no compite con ellas.

Flujos esenciales:
- Registro → perfil → primera mascota.
- Inicio de sesión → feed.
- PawMoment → publicar → feed.
- Cazar → cámara/revisión → publicación.
- Feed → perfil de mascota.
- Perfil → racha y logros.
- Solicitud de amistad → aceptación → publicaciones visibles.
- Paw Hunt → participar → confirmación.
- Grupo → publicación privada → racha.
- Mascota → resumen mensual → recuerdo anterior.

Los recorridos futuros se implementan en sus fases correspondientes.

## 14. Modelo de datos y API

Considera entidades o equivalentes: User, Pet, Friendship/FriendRequest, Post/PhotoMoment, MediaAsset, PostPet, Reaction, Comment, DailyParticipation, PawStreak, AchievementDefinition, UserAchievement, Mission, MissionSubmission, PawPointsTransaction, CosmeticItem, PetCosmetic, PawGroup, PawGroupMembership, GroupPost, GroupStreak, MonthlyMemory, PhotoClassification y Notification.

No crees todas las tablas en la primera migración: introduce datos con cada funcionalidad.

Usa identificadores estables, restricciones de integridad, índices adecuados, paginación, DTO, Bean Validation, transacciones y migraciones versionadas. Evita N+1, exponer directamente entidades JPA o concentrar lógica en controladores.

Versiona la API, por ejemplo bajo `/api/v1`. Define por endpoint método, entrada, validaciones, respuesta, errores y permisos. Genera OpenAPI que coincida con el código real. Algunos recursos posibles: `/auth`, `/users/me`, `/pets`, `/friend-requests`, `/friends`, `/moments`, `/feed/friends`, `/reactions`, `/comments`, `/gamification`, `/missions`, `/points`, `/groups`, `/pets/{petId}/memories`, `/media` y `/notifications`.

## 15. Seguridad, privacidad y fiabilidad

- Contraseñas con hashing seguro y gestión adecuada de tokens.
- Validación y autorización en backend en cada recurso protegido.
- Protección contra IDOR y acceso a publicaciones/grupos ajenos.
- Límites de subida y controles de frecuencia para operaciones sensibles.
- Errores sin secretos ni trazas internas expuestas.
- Variables de entorno; nunca commits de secretos.
- Flujos de eliminación de cuenta y datos asociados.
- Sin ubicación precisa pública por defecto.
- Eliminación de metadatos EXIF sensibles.
- Funciones de bloqueo y reporte cuando corresponda.
- No publiques fotografías de terceros o mascotas ajenas sin permisos adecuados.

## 16. Pruebas y calidad

Backend: prueba autenticación, autorización, validación, mascotas, publicaciones y visibilidad, amistades, rachas, idempotencia de puntos/logros, misiones, permisos de grupos y recuerdos.

Flutter: prueba autenticación, estados de carga/error/vacío, formularios, captura/publicación, navegación, feed, rachas y logros.

Ejecuta los comandos disponibles para análisis Flutter, tests Flutter, compilación y tests Java, migraciones y Docker Compose cuando proceda. **No declares que una comprobación pasó sin haberla ejecutado.** Si falta un servicio externo, explica qué no pudo comprobarse y por qué.

## 17. Roadmap obligatorio

### Fase 0 — Base técnica
Auditoría, estructura, Flutter, Spring Boot, PostgreSQL, Flyway, Docker Compose, almacenamiento de imágenes, convenciones, errores, pruebas, `.env.example`, README, `ARCHITECTURE.md` y `ROADMAP.md`.

Aceptación: la base arranca siguiendo instrucciones documentadas.

### Fase 1 — MVP social
Autenticación, perfil de usuario, mascotas, subida segura, PawMoment (sin bloqueo al terminar la ventana), PawParazzi Mode, amistades, feed de amigos, reacciones, comentarios, PawStreak básico, navegación y pruebas de flujos esenciales.

No implementar todavía muro público, votaciones de Paw Hunt ni IA obligatoria.

Aceptación: un usuario puede registrarse, crear una mascota, publicar fotos y compartirlas con amigos de extremo a extremo.

### Fase 2 — Gamificación y comunidad
Misiones semanales, Paw Hunt, PawPoints, insignias, pantalla de logros, marcos cosméticos, PawSquads, publicaciones privadas de grupos, rachas compartidas, recuerdos mensuales y notificaciones mejoradas.

### Fase 3 — IA y evolución
Analizador intercambiable, clasificación de fotos, edición manual de etiquetas, sugerencias de logros, archivo de personalidad, resúmenes enriquecidos y manejo robusto de fallos/reintentos.

### Fuera del MVP
Muro público de avistamientos, votaciones comunitarias, rankings globales, mensajería privada completa, tienda compleja y generación artística de imágenes.

## 18. Criterios de aceptación del MVP

- Un usuario puede registrarse e iniciar sesión.
- Puede crear y editar mascotas.
- Puede publicar PawMoment incluso después de la ventana inicial.
- Puede publicar fotografías libres.
- El feed solo muestra publicaciones autorizadas.
- Solicitudes y amistades funcionan.
- Reacciones y comentarios funcionan.
- La racha no aumenta más de una vez por día.
- Las fotos se almacenan fuera de PostgreSQL.
- Las reglas de acceso se aplican en servidor.
- Las pantallas principales presentan estados de carga, error y vacío.
- Migraciones y tests relevantes funcionan.
- Las instrucciones se pueden seguir en un entorno limpio.
- No hay secretos en el repositorio ni funciones falsas presentadas como terminadas.

## 19. Primera tarea

Inspecciona el repositorio real y entrega un resumen conciso del estado actual, arquitectura propuesta, riesgos/bloqueos y checklist por fases. Después implementa inmediatamente el siguiente bloque funcional de la fase actual; no te quedes en una propuesta teórica. Ejecuta las verificaciones que puedas, actualiza documentación y cierra indicando qué funciona realmente, qué no has podido verificar y el siguiente bloque concreto.

**Objetivo final: construir PawParazzi de forma incremental como una aplicación móvil real, funcional, testeada y preparada para evolucionar.**
