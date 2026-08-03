# Stack Técnico

> Fuente de verdad para decisiones de producto. Las reglas operativas del
> agente (prohibiciones, estilo, workflow) viven en AGENTS.md en la raíz.

## Entorno
- IDE: VS Code / Antigravity (solo edición de código, sin build local).
- Build environment: GitHub Actions con Xcode 16.x en runners `macos-latest`.
- Lenguaje: Swift 6 con strict concurrency.
- UI: SwiftUI + framework Observation (`@Observable`).
- Arquitectura: MVVM.

## Plataforma
- Target mínimo: iOS 17.0 (necesario para `@Observable`; cubre >90% de
  dispositivos activos).
- Orientación: portrait only.
- Dispositivos: iPhone.

## PhotoKit (decisiones críticas)
- Permiso: `NSPhotoLibraryUsageDescription` con acceso de LECTURA Y ESCRITURA
  (`PHPhotoLibrary.requestAuthorization(for: .readWrite)`), imprescindible
  para eliminar assets.
- IMPORTANTE: la eliminación de assets nativos SIEMPRE muestra el diálogo de
  confirmación del sistema en el primer borrado por lotes. Es comportamiento
  de iOS, no evitable: el roadmap lo contempla en el diseño del flujo.
- Miniaturas: `PHCachingImageManager` con tamaños explícitos; imágenes
  full-size solo en la tarjeta activa.
- Sincronización: `PHPhotoLibraryChangeObserver` para reaccionar a cambios
  externos en la galería.

## Persistencia
- Estado de sesión (marcadas para borrar, progreso) solo en memoria o
  UserDefaults.

## CI/CD
- GitHub Actions con runners `macos-latest`.
- Workflow: compilar, testear y generar `.ipa` firmado con certificados en
  GitHub Secrets.
- Guardarraíl: paso de lint que falla si detecta `URLSession` o imports de
  red (refuerzo de las prohibiciones de AGENTS.md).

## Dependencias externas
- NINGUNA. Código 100% nativo (decisión ligada a la misión de privacidad).