# Roadmap

Cada fase es una feature SDD con su propia carpeta en `spec/features/`
(spec.md + plan.md + tasks.md).

## Fase 1 — Setup y CI/CD (001-setup-y-cicd)
- Proyecto Xcode en `/codigo` con target iOS 17+, Swift 6, strict concurrency complete.
- Workflow de GitHub Actions: compila, ejecuta tests y genera `.ipa` sin firmar.
- Guardarraíl de red en CI (`lint_network.sh`).
- **Estado:** Completada y verificada en CI.

## Fase 2 — Carga de galería (002-interfaz-galeria)
- Solicitud de permisos PhotoKit con los 5 estados manejados (`notDetermined`, `authorized`, `limited`, `denied`, `restricted`).
- Grid de miniaturas con `PHCachingImageManager` inyectado y prefetch.
- Orden: cronológico inverso (más reciente primero).
- Sincronización incremental reactiva vía `PHPhotoLibraryChangeObserver`.
- **Estado:** Completada y verificada en CI.

## Fase 3 — Motor de swipe (003-motor-swipe)
- Pila de tarjetas con gestos: derecha = conservar, izquierda = borrar.
- Reproducción de vídeo nativa (`AVPlayerLayer` / `VideoPlayerView`) en bucle con control de silencio.
- Carga de imágenes a resolución completa sin borradores intermediarios.
- Animación física spring, insignias glassmorphic y respuesta háptica (`UIImpactFeedbackGenerator`).
- Deshabilitación de gesto interactivo de back para evitar salidas accidentales a la Galería.
- Guard atómico de decisiones (`swipeInFlight`).
- Acción "deshacer" de la última decisión con límite de 200 entradas en historial.
- **Estado:** Completada y verificada en CI.

## Fase 4 — Eliminación por lotes (004-eliminacion-photokit)
- Resumen de sesión: nº de marcadas y espacio estimado a liberar (`SizeEstimate` con prefijo `≥`).
- Confirmación explícita del usuario + diálogo nativo del sistema.
- Borrado con `PHAssetChangeRequest.deleteAssets` (papelera nativa "Eliminados recientemente").
- Manejo explícito de cancelación por usuario (`PHPhotosErrorDomain` código `3072`).
- **Estado:** Completada y verificada en CI.

## Fase 5 — Persistencia de Sesión (005-persistencia-sesion)
- Guardado automático del estado de la sesión en `UserDefaults` tras cada swipe o deshacer.
- Detección al abrir la app y botón de **"Continuar sesión anterior (N fotos clasificadas)"** en la Galería.
- Limpieza automática de la sesión guardada tras un borrado masivo exitoso.
- Suite de pruebas `SessionPersistenceTests`.
- **Estado:** Completada y verificada en CI.