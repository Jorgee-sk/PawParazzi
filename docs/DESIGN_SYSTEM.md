# Sistema de diseño — Figma → Flutter

Fuente de verdad: archivo de Figma `6c4Ai7A2Xm0Hb9lSXmZ8ry` («Untitled»), inspeccionado por MCP el 12/10/2026.

## Inventario del archivo

Una sola página, **01 · Marca & Sistema**, con:

| Sección | Frames | Uso en la app |
|---|---|---|
| Brand & Foundations | Marca y fundamentos; Datos demo y contrato móvil | Paleta, tipografía, espaciado, contrato móvil |
| Design System | Navegación y controles; Fotografía y progreso; Mensajes y recuperación | Muestras de uso de cada componente |
| PawParazzi · Componentes principales | 25 familias / 50 componentes | Implementados como widgets (ver tabla) |

**No hay frames de pantallas completas** en el archivo: las pantallas se componen con los componentes
y el contrato móvil documentado en Figma. Cuando se añadan frames de pantalla, hay que revisar las
pantallas frente a ellos.

## Contrato móvil (Figma «iOS / Android / Flutter»)

- Viewport de referencia 390 × 844; área superior 44 (en Flutter: `SafeArea`/`MediaQuery`, nunca fijo).
- Header 68; navegación + safe area 88; margen lateral 24; contenido flexible.
- Modal de captura sin navegación inferior. Navegación fija; el teclado no tapa la acción.
- Controles ≥ 44 px, botones 52 px, etiquetas habladas para iconos, estados no solo por color.

## Tokens (`mobile/lib/core/theme/`)

| Figma | Flutter |
|---|---|
| `background/cream` #FFF8F0, `surface/white`, `brand/plum` #573B52, `accent/coral` #FF796C, `support/lavender` #E8DFFF, `reward/butter` #FFE5A3, `positive/mint` #CDEBDD | `PawColors.*` |
| `text/primary` #29242B, `text/tone-1` #655A66 (metadatos), `text/secondary` #817782 (no en texto pequeño) | `PawColors.textPrimary/textMuted/textSecondary` |
| `border/subtle`, `surface/tone-2…5` (skeleton, deshabilitado, error, cámara) | `PawColors.*` |
| `spacing/4…48` | `PawSpacing` |
| `radius/16·20·24` (entrada · mensaje · foto) | `PawRadius` |
| `PawParazzi/Elevation/Subtle` | `PawShadows.subtle` |
| Estilos `PawParazzi/Display…Caption` (Manrope títulos, Inter texto) | `PawText` + fuentes en `assets/fonts` |

## Componentes

| Componente Figma | Widget | Estado |
|---|---|---|
| Button (Primary/Secondary/Loading/Disabled/Compact) | `PawButton` | ✅ |
| Navigation (5 pestañas) | `PawNavBar` | ✅ |
| Header (Brand/Detail) | `PawBrandHeader`, `PawDetailHeader` | ✅ (campana omitida: notificaciones no implementadas) |
| Input (Default/Focus/Error) | `PawTextField` | ✅ |
| UserAvatar / PetAvatar | `UserAvatar`, `PetAvatar` | ✅ (marco equipado: fase 2) |
| PetSelector | `PetSelectorTile` | ✅ |
| Capture (shutter) | `_Shutter` en `CaptureScreen` | ✅ |
| PostType / CategoryTag / Etiqueta | `PawTag`, `PawChoiceTag` | ✅ |
| Post | `PostCard` | ✅ (cariños y comentarios) |
| PawStreak (Active/Interrupted) | `PawStreakCard` | ✅ |
| Toast / ErrorMessage / Mensaje contextual | `PawMessage`, `showPawToast` | ✅ |
| EmptyState, Skeleton, ConfirmDialog | `PawEmptyState`, `PostSkeleton`, `showPawConfirm` | ✅ |
| Switch | — | pendiente (ajustes de notificaciones) |
| ParticipationCalendar, Achievement, PawPoints, CosmeticFrame, Squad, WeeklyMission, MemoryCard, LoadingState | — | fase 2 |

## Pantallas (plan e implementación)

| Pantalla | Componentes | Estado |
|---|---|---|
| Login / Registro | Marca reducida, Input, Button, Mensaje | ✅ conectado |
| Onboarding perfil (1/2) | Etiqueta, Input, Button | ✅ conectado |
| Onboarding / nueva / editar mascota (2/2) | Avatar mascota, Etiquetas, Input, Button, ConfirmDialog | ✅ conectado |
| Inicio | Header Brand, PawMoment (Mensaje + Button), PawStreak, Post, Skeleton, EmptyState | ✅ conectado |
| Capturar / PawMoment | Disparador sobre `surface/tone-5`, Button secundario, ErrorMessage permiso | ✅ (cámara del sistema; visor integrado pendiente) |
| Revisar y publicar | Foto radio 24, PostType, PetSelector, Input, CategoryTag, Button loading, ErrorMessage «Tu foto está a salvo», ConfirmDialog «¿Descartar este borrador?» | ✅ conectado |
| Perfil de mascota | Header Detail, PetAvatar, Etiquetas, Post | ✅ conectado |
| Perfil | Header, UserAvatar, PawStreak, PetSelector, ConfirmDialog cierre de sesión | ✅ conectado |
| Amistades | Header Detail, Input, Button compacto, Toast «Solicitud enviada», EmptyState | ✅ conectado |
| Comentarios | Header Detail, UserAvatar, Input, Button compacto, EmptyState, ConfirmDialog | ✅ conectado |
| Editar perfil | Header Detail, UserAvatar, Input, Button | ✅ conectado |
| Paw Hunt, Grupos | EmptyState + etiqueta «Fase futura · no disponible» | Marcadas explícitamente como no disponibles |

## Decisiones donde Figma no define el detalle

- **Cariño enviado**: Figma no tiene estado «reaccionado»; se usa la píldora lavanda (patrón de pestaña
  activa) y el texto «· incluido el tuyo», para no depender solo del color.
- **Etiqueta seleccionable**: Figma solo tiene etiquetas estáticas; la seleccionada es lavanda con check,
  la no seleccionada blanca con borde sutil.
- **Tarjeta PawMoment**: construida con el patrón «Mensaje contextual» (butter cuando la ventana está
  abierta, lavanda fuera de ella, mint cuando ya se participó) y el icono `zap` (coral = flash).
- **PawStreak sin historial**: variante lavanda «Tu primera racha empieza con un PawMoment».
- **Icono de cámara**: la exportación SVG del MCP omitía el círculo del objetivo (visible en el render de
  Figma). Se añadió en `nav_camera*.svg` y `camera.svg` con la geometría de Lucide escalada a 22 px.
- **Textos con «cazar»**: por decisión del dueño del producto se evita el verbo cuando puede leerse como cazar
  animales. La pestaña «Cazar» pasa a «Capturar», el tipo «Caza libre» a «Foto libre», «Empezar a cazar» a
  «Entrar en PawParazzi». **Figma sigue con los nombres antiguos** (componentes Navigation y PostType): hay que
  actualizarlo allí. El lema «Caza lo inesperado» de la pantalla de inicio de sesión no se ha tocado.
- **Pantallas anchas**: Figma solo define móvil (390 px); en web y tablet el contenido se centra con 560 px máx.
- **Contenido demo** de Figma (Elena, Nube, Milo, fotos): no se incluye en la app. Los vacíos son reales.
