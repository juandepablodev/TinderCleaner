# Reglas y Convenciones del Proyecto (AGENTS.md)

> Contrato operativo para cualquier agente de código que trabaje
> en este repositorio. Lee este archivo COMPLETO antes de escribir una sola
> línea. Si algo aquí contradice tu intuición, gana este archivo.

## 1. Stack Tecnológico
- Lenguaje: Swift 6.x (strict concurrency habilitado cuando sea posible).
- Interfaz: SwiftUI (UIKit solo mediante `UIViewRepresentable` si un control
  nativo no existe en SwiftUI, justificándolo en la spec).
- Frameworks nativos: PhotoKit (gestión de galería), Combine/Swift Concurrency.
- Persistencia: SwiftData o ficheros en el sandbox de la app (sin backends).
- Target: iOS 17+ (ajustar según la spec vigente).
- IDE: VS Code / Antigravity (solo edición de código, sin build local).
- Build: GitHub Actions (macos-latest) - ÚNICO entorno de compilación.
- Testing: GitHub Actions con simulador de iOS.
- Dependencias: SOLO código nativo. SPM únicamente si la spec lo justifica.

## 2. Prohibiciones Estrictas (SEGURIDAD Y PRIVACIDAD)
- PRIVACIDAD ABSOLUTA: la aplicación es 100% local y privada.
- RED: está TERMINANTEMENTE PROHIBIDO incluir `URLSession`, frameworks de
  analítica, tracking, telemetría, llamadas de red o dependencias externas
  con acceso a internet. Ni siquiera "opcionales" o "degradadas".
- `Info.plist` NO debe declarar `NSAllowsArbitraryLoads` ni ningún
  permiso de red. Los únicos permisos permitidos son los de PhotoKit
  (`NSPhotoLibraryUsageDescription`, con el texto exacto definido en /spec).
- AISLAMIENTO: la app debe funcionar al 100% en Modo Avión y cumplir el
  Sandbox de Apple. Sin App Groups salvo que una spec lo requiera.
- DATOS: nunca escribir imágenes del usuario fuera del sandbox ni en logs.
  Prohibido loggear rutas, metadatos EXIF o identificadores de assets.

## 3. Patrones de Diseño y Convenciones
- Arquitectura: MVVM con `@Observable` (Observation framework). Vistas
  delgadas: toda la lógica va en ViewModels o servicios dedicados.
- Concurrencia: `async/await` y concurrencia estructurada (`async let`,
  `TaskGroup`). Prohibidos completion handlers anidados y `Task {}`
  sin cancelación en código de producción.
- Estado: un ViewModel por pantalla/feature. Estado mutable solo en el
  ViewModel; las vistas reciben datos y emiten acciones.
- Memoria (CRÍTICO con PhotoKit):
  - Usar `PHCachingImageManager` con `startCachingImages`/`stopCachingImages`,
    nunca cargar imágenes full-size en colecciones.
  - Miniaturas con `targetSize` explícito; full-size solo bajo demanda.
  - Evitar retain cycles: `[weak self]` en closures que capturen self,
    y cancelar `PHImageRequestID` en `onDisappear`/deinit.
  - Responder a `PHPhotoLibraryChangeObserver` para mantener el fetch
    actualizado sin recargar todo.
- Estilo de código: indentación de 2 espacios, nombres en inglés, comentarios solo
  para explicar el "porqué", nunca el "qué".
- Errores: tipos `Error` propios por dominio; nunca `try!` ni force-unwrap
  fuera de tests.

## 4. Flujo de Trabajo del Agente
1. ANTES de implementar, presenta el plan y espera aprobación.
2. Implementa SOLO lo que pide la spec.
3. Commit + push a rama `dev`.
4. GitHub Actions compila y ejecuta tests.
5. Si CI falla, el agente lee los logs y corrige.
6. Solo mergear a `main` cuando CI pase al 100%.

## 5. Estructura del Proyecto (SDD)
El desarrollo se rige por Spec-Driven Development (SDD):
- La carpeta `/spec` es la fuente de verdad. Cada spec define: objetivo,
  criterios de aceptación testeables, qué está fuera de scope, restricciones
  y casos límite.
- NUNCA escribas código de una feature sin spec. Si no existe, propón la
  spec primero.
- Si el código y la spec divergen, se corrige la spec o el código, pero
  ambos deben quedar alineados antes de mergear.
- Las verificaciones de performance y memoria se hacen SOLO en CI.
- Los criterios de cierre deben ser verificables en GitHub Actions.
- Fase 2: "60 fps con 5.000 fotos" se verifica con tests automatizados en simulador CI.

Estructura de carpetas:
TinderPhoto
├── AGENTS.md            ← El arnés o "guardarraíl" del proyecto
├── spec/                ← Estructura base del Spec-Driven Development
│   ├── constitution/    
│   │   ├── mission.md   ← Qué construimos y para quién
│   │   ├── tech-stack.md← Tecnologías y convenciones
│   │   └── roadmap.md   ← Orden de las features a desarrollar
│   └── features/        ← Carpeta para cada funcionalidad
│          ├── 001-setup-y-cicd/ 
│          │   ├── spec.md  ← Qué hace esta feature y criterios de aceptación
│          │   ├── plan.md  ← Cómo se implementa
│          │   └── tasks.md ← Checklist de tareas granulares
│          └── 002-interfaz-galeria/
│                  
└── código/              ← El código que generará el agente (tu proyecto Xcode)

## 6. Testing
- Framework: Swift Testing (`@Test`, `#expect`). XCTest solo para UI tests.
- Todo nuevo ViewModel/servicio con lógica no trivial lleva tests.
- Testea comportamiento, no implementación interna.
- Mockea PhotoKit detrás de un protocolo para que los tests no toquen
  la galería real.
- Ejecuta los tests antes de cualquier PR.

## 7. Estilo de Commits y CI/CD
- Commits en formato Conventional Commits: `feat:`, `fix:`, `refactor:`,
  `test:`, `docs:`, `chore:` — mensajes en inglés, imperativo.
- Todo código que pase a `main` debe compilar Y pasar los tests.
- `.github/workflows/build.yml` debe compilar el proyecto y generar un
  `.ipa` con los certificados de distribución configurados (secrets de
  GitHub, nunca certificados en el repo).
- El CI debe incluir un paso de lint que falle si se detecta `URLSession`
  o imports de frameworks de red (guardarraíl de la sección 2).