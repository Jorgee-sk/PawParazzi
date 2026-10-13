# PawParazzi

> No busques la foto perfecta. Caza el momento más inesperado de tu mascota.

App social para capturar y compartir fotos espontáneas de mascotas con amistades.

- Qué está hecho y qué falta: [ROADMAP.md](ROADMAP.md)
- Cómo está construido: [ARCHITECTURE.md](ARCHITECTURE.md)
- Diseño (Figma → Flutter): [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md)

El proyecto tiene tres piezas que se arrancan por separado, cada una en su terminal:

| Pieza | Carpeta | Qué es |
|---|---|---|
| Servicios | `compose.yaml` | PostgreSQL (datos), SeaweedFS (fotos) y revisión de fotos, en contenedores Podman |
| Backend | `backend/` | API en Spring Boot, en `http://localhost:8080` |
| App | `mobile/` | App Flutter |

## Requisitos

- **Java 21**. Maven no hace falta: se descarga solo con `mvnw`.
- **Flutter 3.44** o superior.
- **Podman** con la máquina en marcha, y **podman-compose** (`pip install --user podman-compose`).
  Solo para el modo completo; el modo rápido no los necesita.

## Arranque rápido (sin contenedores)

Para probar la app sin Podman. El backend guarda los datos en un fichero local (H2) y las fotos en
`backend/data/media`. Solo para desarrollo.

Terminal 1, backend:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-backend.ps1 -H2
```

Terminal 2, app:

```powershell
cd mobile
flutter pub get
flutter run -d chrome
```

Espera a ver `Started PawparazziBackendApplication` en la terminal 1 antes de usar la app.

## Arranque completo (PostgreSQL + SeaweedFS con Podman)

### 1. Preparación (solo la primera vez)

1. Crea y arranca la máquina de Podman, desde Podman Desktop o con:

   ```powershell
   podman machine init
   podman machine start
   ```

2. Instala podman-compose:

   ```powershell
   pip install --user podman-compose
   ```

3. Crea el fichero de configuración a partir de la plantilla:

   ```powershell
   copy .env.example .env
   ```

   Abre `.env` y rellena con valores aleatorios `DB_PASSWORD`, `JWT_SECRET` (mínimo 32 caracteres),
   `S3_ACCESS_KEY` y `S3_SECRET_KEY`. Cambia también `STORAGE_PROVIDER=local` por `STORAGE_PROVIDER=s3`
   para que las fotos se guarden en SeaweedFS. `.env` no se sube al repositorio.

### 2. Cada vez que quieras trabajar

Terminal 1, servicios (termina solo cuando están listos):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\dev-services.ps1
```

Terminal 1, backend (se queda en marcha; `Ctrl+C` para pararlo):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run-backend.ps1
```

Terminal 2, app:

```powershell
cd mobile
flutter pub get
flutter run -d chrome
```

### 3. Al terminar

```powershell
powershell -ExecutionPolicy Bypass -File scripts\dev-services.ps1 -Down
```

Los datos se conservan para la próxima vez. Para borrarlos y empezar de cero:
`python -m podman_compose down -v`.

## Revisión automática de fotos

Cada foto se revisa antes de guardarse con un modelo abierto (CLIP) que corre en tu propio contenedor
`moderation`: no hay coste por foto ni se envían imágenes a terceros. Se rechazan las publicaciones y fotos
de mascota donde no aparece ningún animal real, y cualquier imagen con violencia o contenido sexual. La foto
de perfil de una persona no necesita mostrar un animal.

- Se activa con `MODERATION_PROVIDER=local` en `.env` (con `none` se acepta cualquier imagen válida).
- `scripts\dev-services.ps1` arranca el contenedor. La primera vez construye la imagen y descarga el modelo
  (unos 600 MB); después arranca en segundos. Usa alrededor de 1 GB de memoria y tarda unos 30 ms por foto en CPU.
- Si el servicio no responde, por defecto la foto se acepta sin revisar (`MODERATION_ON_ERROR=allow`).

Cómo ajustarlo y qué limitaciones tiene: [moderation/README.md](moderation/README.md).

## Cómo comprobar que funciona

| Qué | Dónde |
|---|---|
| Backend vivo | <http://localhost:8080/actuator/health> debe responder `{"status":"UP"}` |
| Documentación de la API | <http://localhost:8080/swagger-ui.html> |
| Contenedores | `podman ps` debe mostrar `postgres`, `seaweedfs` y `moderation` como `healthy` |
| Revisión de fotos | <http://localhost:8090/healthz> debe responder `{"status":"ok",...}` |

En la app: crea una cuenta, elige nombre de usuario, añade tu primera mascota y publica una foto.
Para probar el feed de amigos, crea una segunda cuenta en otra ventana del navegador y envíale una
solicitud por nombre de usuario desde **Perfil → Amigos y solicitudes**.

## La app en otros dispositivos

| Dónde | Comando |
|---|---|
| Navegador | `flutter run -d chrome` |
| Emulador de Android | `flutter run` (usa `http://10.0.2.2:8080` automáticamente) |
| Móvil físico en la misma red | `flutter run --dart-define=API_BASE_URL=http://IP_DE_TU_PC:8080` |

## Tests

```powershell
cd backend
.\mvnw.cmd test
```

```powershell
cd mobile
flutter analyze
flutter test
```

Test del almacenamiento contra SeaweedFS (con los servicios en marcha y los valores de tu `.env`):

```powershell
cd backend
$env:S3_IT_ENDPOINT = "http://localhost:8333"
$env:S3_ACCESS_KEY = "..."
$env:S3_SECRET_KEY = "..."
.\mvnw.cmd test "-Dtest=S3StorageServiceIT"
```

## Sin los scripts (Linux, macOS o Git Bash)

```bash
cp .env.example .env               # y rellena los valores
podman compose up -d               # o: python -m podman_compose up -d
cd backend
set -a && . ../.env && set +a      # carga las variables de .env
./mvnw spring-boot:run
```

Modo rápido sin contenedores:

```bash
cd backend
export JWT_SECRET="$(openssl rand -base64 48)"
SPRING_PROFILES_ACTIVE=h2 ./mvnw spring-boot:run
```

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `No se puede cargar el archivo ... la ejecución de scripts está deshabilitada` | Lanza el script con `powershell -ExecutionPolicy Bypass -File ...`, como en esta guía |
| El backend no arranca y menciona `JWT_SECRET` | Falta `JWT_SECRET` en `.env` o tiene menos de 32 caracteres |
| El backend no conecta con la base de datos | Arranca antes los servicios con `scripts\dev-services.ps1` |
| `podman` no se reconoce como comando | Abre una terminal nueva tras instalar Podman, o comprueba que la máquina está en marcha en Podman Desktop |
| `crun: controller 'pids' is not available` al arrancar cualquier contenedor | Entra en la máquina con `podman machine ssh`, crea `/etc/containers/containers.conf.d/50-cgroupfs.conf` con las líneas `[engine]` y `cgroup_manager = "cgroupfs"`, y ejecuta `sudo systemctl restart podman.socket` |
| Los contenedores están `healthy` pero `scripts\dev-services.ps1` dice que un puerto no responde | `podman machine stop`, luego `podman machine set --user-mode-networking=true`, luego `podman machine start` |
| Se rechaza una foto normal de tu mascota | Revisa las puntuaciones con `python moderation/test_images.py carpeta-con-la-foto` y ajusta el umbral (ver `moderation/README.md`) |
| La app muestra «No hay conexión con PawParazzi» | El backend no está en marcha, o la app apunta a otra dirección (ver «La app en otros dispositivos») |

Los dos fallos de Podman de la tabla aparecieron con Podman 6.0.2 y WSL 3.0.1 en Windows 11. En el equipo
de desarrollo ya están corregidos.

## Estado de las verificaciones

Comprobado el 12/10/2026 en Windows 11 con Podman 6.0.2: los dos modos de arranque, las migraciones en
PostgreSQL 17.11, el almacenamiento en SeaweedFS 4.48 y el flujo completo de la API (por HTTP, sin la app).
De la app están comprobados los tests, la compilación web y la pantalla de inicio de sesión en navegador;
falta recorrer el flujo completo a mano y probarla en dispositivos iOS y Android.

## Créditos

Tipografías Inter y Manrope (SIL Open Font License 1.1), vía Fontsource. Iconos exportados del archivo de
Figma del proyecto (estilo Lucide).
