# Instrucciones del repositorio PawParazzi

Antes de planificar o modificar el proyecto, lee `MASTER_PROMPT_PAWPARAZZI.md` y síguelo como especificación funcional y guía de producto.

Reglas permanentes:
- Inspecciona primero el estado real del repositorio y reutiliza lo que ya funcione.
- Sigue el roadmap definido en el master prompt y prioriza una funcionalidad de extremo a extremo cada vez.
- No te limites a planificar: después de inspeccionar y comunicar brevemente el plan, implementa el siguiente bloque funcional.
- No marques tareas ni tests como completados si no los has verificado.
- Actualiza `ROADMAP.md`, `ARCHITECTURE.md` y README cuando corresponda.
- No inventes datos, resultados de IA ni integraciones funcionales.
- No introduzcas secretos ni credenciales en el repositorio.
- Para el diseño visual, usa el proyecto de Figma conectado por MCP como fuente de verdad. Inspecciona los frames, variables, componentes y layouts relevantes antes de implementar interfaces; no reconstruyas el diseño de memoria si puedes consultar Figma.
- Si el usuario proporciona un enlace o identificador de Figma, utilízalo para localizar el archivo/frame adecuado. Si MCP no está conectado, explica el bloqueo y continúa con trabajo independiente de Figma.

## Estado y comandos (actualizado 12/10/2026)
- Estructura: `backend/` (Spring Boot 3.5, Java 21) · `mobile/` (Flutter) · docs en `ARCHITECTURE.md`, `ROADMAP.md`, `docs/DESIGN_SYSTEM.md`.
- Figma: archivo `6c4Ai7A2Xm0Hb9lSXmZ8ry`, página «01 · Marca & Sistema» (sistema de diseño, sin frames de pantalla). Mapeo de tokens/componentes en `docs/DESIGN_SYSTEM.md`.
- Backend: `cd backend && ./mvnw test`; ejecutar sin contenedores con `SPRING_PROFILES_ACTIVE=h2` y `JWT_SECRET` (≥32 bytes).
- Flutter: `cd mobile && flutter analyze && flutter test`.
- Contenedores: se usa **Podman**, no Docker (decisión del usuario, 12/10/2026). Donde el master prompt dice «Docker Compose», léase `podman compose` con `compose.yaml`. Almacenamiento S3 local: SeaweedFS (MinIO ya no publica imágenes). Usa imágenes con nombre completo (`docker.io/...`). En Windows: `scripts\dev-services.ps1` levanta los servicios (requiere `podman-compose` vía pip y `.env`); problemas conocidos de la máquina en el README.
- Revisión de fotos: servicio propio en `moderation/` (CLIP en CPU, contenedor `moderation`). No usar APIs de pago por foto (decisión del usuario, 13/10/2026). Tras cambiar `moderation/prompts.py`, reconstruir la imagen y pasar `moderation/test_images.py`.
- Nombres de producto: «Capturar» (no «Cazar») y «Foto libre» (no «Caza libre»). No editar migraciones Flyway ya aplicadas, ni siquiera sus comentarios.
