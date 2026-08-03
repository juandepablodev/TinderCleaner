# Roadmap

Cada fase es una feature SDD con su propia carpeta en `spec/features/`
(spec.md + plan.md + tasks.md). No se empieza una fase sin que la anterior
esté mergeada y verificada en CI.

## Fase 1 — Setup y CI/CD (001-setup-y-cicd)
- Proyecto Xcode en `/codigo` con target iOS 17+, Swift 6, strict concurrency.
- Workflow de GitHub Actions: compila, ejecuta tests y genera `.ipa` firmado.
- Guardarraíl de red en CI.
- **Criterio de cierre:** un push a `main` produce un `.ipa` instalable.

## Fase 2 — Carga de galería (002-interfaz-galeria)
- Solicitud de permisos PhotoKit con estados manejados (autorizado, denegado,
  limitado: cada uno con su UI específica).
- Grid de miniaturas con `PHCachingImageManager` y prefetch.
- Orden: cronológico inverso (más reciente primero).
- **Criterio de cierre:** scroll fluido (60 fps) con una galería de +5.000
  assets en dispositivo real, sin picos de memoria.

## Fase 3 — Motor de swipe (003-motor-swipe)
- Pila de tarjetas con gestos: derecha = conservar, izquierda = marcar para
  borrar.
- Pre-carga de la imagen full-size de la tarjeta activa y las 2 siguientes.
- Botones de fallback accesibles (conservar/borrar/deshacer) + VoiceOver.
- Acción "deshacer" de la última decisión.
- **Criterio de cierre:** el gesto responde en <100 ms y deshacer restaura
  siempre el estado correcto.

## Fase 4 — Eliminación por lotes (004-eliminacion-photokit)
- Resumen de sesión: nº de marcadas y espacio estimado a liberar.
- Confirmación explícita del usuario + diálogo nativo del sistema.
- Borrado con `PHAssetChangeRequest.deleteAssets` (papelera nativa, nunca
  irreversible).
- Manejo de errores parciales (assets que fallan se reportan, no se pierden).
- **Criterio de cierre:** los assets eliminados aparecen en "Eliminados
  recientemente" y la app refleja la galería actualizada sin reiniciar.
