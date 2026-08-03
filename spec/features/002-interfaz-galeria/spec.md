# Especificación Funcional y Técnica (SDD) — Feature 003: Motor de Swipe y Tarjetas Interactivas

> **ID Feature:** `003-motor-swipe`  
> **Estado:** Especificado  
> **Versión target:** iOS 17.0+ | Swift 6.0 (Strict Concurrency Complete)  
> **Ubicación del código:** `/codigo/TinderCleaner/Features/SwipeEngine`  
> **ViewModel central:** `SwipeEngineViewModel`

---

## 1. Visión General y Objetivos

La feature **003-motor-swipe** constituye el núcleo de interacción de **TinderCleaner**. Proporciona una interfaz basada en una pila de tarjetas deslizables estilo Tinder, donde el usuario clasifica velozmente su galería mediante gestos táctiles o botones de acción.

### Objetivos Clave
1. Implementar la pila de tarjetas interactivas con gestos de arrastre (`DragGesture`), respuesta física fluida (`Spring`) y visualización de intenciones ("CONSERVAR" en verde a la derecha, "ELIMINAR" en rojo a la izquierda).
2. Garantizar una ventana de precarga asíncrona de 3 imágenes a resolución de pantalla (tarjeta activa `i`, e `i+1`, `i+2`) liberando inmediatamente la memoria de las tarjetas descartadas.
3. Proveer una pila de decisiones en memoria con funcionalidad "Deshacer" (Undo) instantánea que revierta la última clasificación y restaure la tarjeta con animación física.
4. Incluir botones de acción accesibles en pantalla y soporte nativo para `accessibilityReduceMotion`.

---

## 2. Criterios de Aceptación (Medibles y Testeables)

### Criterio 3.1: Clasificación por Gestos y Umbrales
- **Given** la tarjeta superior activa en la pila.
- **When** el usuario la arrastra a la derecha superando +120 pt de desplazamiento X o una velocidad horizontal positiva `> 500 pt/s`.
- **Then** la tarjeta se desliza fuera de pantalla hacia la derecha, marcando el asset como `kept` (conservado) y avanzando a la siguiente tarjeta.
- **When** el usuario la arrastra a la izquierda superando -120 pt de desplazamiento X o velocidad `<-500 pt/s`.
- **Then** la tarjeta se desliza hacia la izquierda, marcando el asset como `pendingDeletion` (marcado para borrar) y avanzando a la siguiente.
- **When** el arrastre no supera los umbrales al soltar el dedo.
- **Then** la tarjeta regresa a la posición inicial (0,0) mediante una animación de muelle `Spring(duration: 0.3, bounce: 0.2)`.

### Criterio 3.2: Ventana de Pre-carga Asíncrona (3 Tarjetas) y Gestión de Memoria
- **Given** una secuencia de assets en la pila.
- **When** la tarjeta `i` está en pantalla.
- **Then** el motor pre-carga de forma asíncrona mediante `PHImageManager` la versión full-screen (tamaño de pantalla del dispositivo) de los índices `i`, `i+1` e `i+2`.
- **And** en cuanto la tarjeta `i` es swipeada, su referencia de imagen full-size se libera de memoria (dealloc) y el índice `i+3` entra en la cola de precarga.
- **And** la huella de memoria (RAM) no excede los **150 MB** durante una sesión de 500 swipes consecutivos.

### Criterio 3.3: Mecanismo de Deshacer (Undo Stack)
- **Given** al menos un asset clasificado previamente en la sesión actual.
- **When** el usuario presiona el botón "Deshacer" (Undo).
- **Then** se desapila la última decisión registrada en la pila de historial.
- **And** la tarjeta correspondiente reaparece desde el borde de pantalla y regresa al tope de la pila con animación física.
- **And** el contador de elementos pendientes de eliminación se actualiza inmediatamente.

### Criterio 3.4: Botones de Acción Accesibles y Reduce Motion
- **Given** la interfaz del motor de swipe.
- **When** el usuario prefiere no usar gestos y toca el botón de "Check Verde" (Conservar) o "Papelera Roja" (Eliminar).
- **Then** se ejecuta la misma acción de clasificación con su animación correspondiente.
- **And** si `accessibilityReduceMotion` está activado en Ajustes de iOS, los gestos y animaciones de arrastre se sustituyen por fundidos suaves (`.opacity`), respetando las guías de accesibilidad de Apple.

---

## 3. Fuera de Alcance (Out of Scope)

1. Eliminación física de archivos en PhotoKit (Feature 004).
2. Edición o recorte de fotos/vídeos.
3. Persistencia de la sesión en disco (el estado vive exclusivamente en memoria durante la sesión).

---

## 4. Diseño Arquitectónico y Modelos de Datos

### 4.1 Estado de Clasificación y Pila de Historial

```swift
import Foundation
import SwiftUI
import Photos

public enum SwipeDecision: Sendable, Equatable {
    case keep
    case delete
}

public struct ClassifiedAsset: Identifiable, Sendable, Equatable {
    public let asset: AssetModel
    public let decision: SwipeDecision
    public let timestamp: Date
    
    public var id: String { asset.id }
}

@Observable
@MainActor
public final class SwipeEngineViewModel {
    // Assets pendientes por revisar
    public private(set) var remainingAssets: [AssetModel] = []
    
    // Tarjeta activa (índice 0) y siguiente (índice 1)
    public var currentAsset: AssetModel? { remainingAssets.first }
    public var nextAsset: AssetModel? { remainingAssets.dropFirst().first }
    
    // Pila de historial para Undo
    public private(set) var historyStack: [ClassifiedAsset] = []
    
    // Caché en memoria restringida a 3 imágenes full-screen
    private var imageCache: [String: UIImage] = [:]
    private var activeRequests: [String: PHImageRequestID] = [:]
    
    private let photoService: PhotoLibraryServiceProtocol
    
    public init(assets: [AssetModel], photoService: PhotoLibraryServiceProtocol) {
        self.remainingAssets = assets
        self.photoService = photoService
        preloadWindow()
    }
    
    public func processDecision(_ decision: SwipeDecision) {
        guard let asset = remainingAssets.first else { return }
        
        let classified = ClassifiedAsset(asset: asset, decision: decision, timestamp: Date())
        historyStack.append(classified)
        
        // Eliminar asset procesado y liberar su caché
        let removed = remainingAssets.removeFirst()
        imageCache.removeValue(forKey: removed.id)
        
        // Actualizar ventana de precarga para los próximos 3
        preloadWindow()
    }
    
    public func undoLastDecision() {
        guard let lastClassified = historyStack.popLast() else { return }
        
        // Reinsertar al inicio de la pila
        remainingAssets.insert(lastClassified.asset, at: 0)
        preloadWindow()
    }
    
    private func preloadWindow() {
        let window = remainingAssets.prefix(3)
        // Invoca petición asíncrona de imagen a resolución de pantalla
    }
}
```

---

## 5. Diseño de Interfaz de Usuario y Gestos SwiftUI

### 5.1 Jerarquía de Vistas
```text
SwipeEngineContainerView
├── CardStackView (ZStack de 2 tarjetas: fondo y frente)
│   ├── CardView (Siguiente tarjeta - scale 0.95, opacity 0.8)
│   └── CardView (Tarjeta activa - gestos DragGesture, rotationEffect, offset)
│       ├── OverlayBadgeView ("CONSERVAR" verde si offset.width > 0)
│       └── OverlayBadgeView ("ELIMINAR" rojo si offset.width < 0)
└── ActionBarView (HStack de botones inferiores)
    ├── UndoButton (Habilitado solo si historyStack no está vacío)
    ├── DeleteButton (Izquierda - Papelera)
    └── KeepButton (Derecha - Corazón/Check)
```

### 5.2 Física del Arrastre y Rotación
La rotación de la tarjeta activa se calcula dinámicamente en función de la distancia de arrastre horizontal:
$$\text{Angulo (grados)} = \frac{\text{translation.width}}{20.0}$$

```swift
CardView(asset: asset, image: image)
    .offset(x: offset.width, y: offset.height)
    .rotationEffect(.degrees(Double(offset.width / 20.0)))
    .gesture(
        DragGesture()
            .onChanged { gesture in
                offset = gesture.translation
            }
            .onEnded { gesture in
                handleDragEnd(translation: gesture.translation, velocity: gesture.velocity)
            }
    )
```

---

## 6. Estrategia de Rendimiento y Memoria

1. **Límite Estricto de Renderizado:**
   - La `ZStack` renderiza **únicamente 2 tarjetas** simultáneamente a nivel visual (la activa y la inmediatamente posterior).
   - Renderizar más de 2 tarjetas en el árbol de SwiftUI degrada el rendimiento a menos de 60 fps durante gestos continuos.
2. **Imágenes Display-Size vs Full-Resolution:**
   - Para la tarjeta activa, se solicita una imagen con `targetSize` equivalente a `UIScreen.main.bounds.size * displayScale` y `contentMode: .aspectFit`.
   - Queda estrictamente prohibido cargar la imagen de resolución original (e.g. 48 Megapíxeles = 192 MB sin comprimir) salvo que el usuario haga zoom explícito.
3. **Liberación Inmediata de Memoria:**
   - En cuanto se descarta una tarjeta, la clave de su imagen se elimina de `imageCache`.

---

## 7. Casos Límite y Manejo de Errores

| Caso Límite | Comportamiento Esperado | Solución de Diseño |
|---|---|---|
| Fin de la cola de fotos (0 pendientes) | La vista pasa automáticamente a la pantalla de Resumen de Sesión (`SessionSummaryView`). | Condición `remainingAssets.isEmpty` activa navegación. |
| Swipe ultrarrápido (múltiples swipes en < 1 segundo) | La pila responde sin bloqueo, encolando las decisiones en el ViewModel. | La precarga asíncrona prioriza siempre la tarjeta visible `i`. |
| Vídeos pesados en la tarjeta activa | Muestra la miniatura estática de portada con indicador de reproducción y duración. | El vídeo no se reproduce automáticamente para preservar batería y memoria. |
| Deshacer cuando la pila de historial está vacía | El botón "Deshacer" está deshabilitado visualmente (`disabled(historyStack.isEmpty)`). | Previene excepciones de índice fuera de rango. |

---

## 8. Guardarraíles de Verificación en CI

1. **Unit Tests del State Machine (`SwipeEngineViewModelTests`):**
   - Verificar que `processDecision(.keep)` actualiza `historyStack` y avanza `remainingAssets`.
   - Verificar que `undoLastDecision()` restaura exactamente el asset anterior en el tope de la cola.
   - Medir la velocidad de ejecución de 1.000 operaciones de swipe en tests unitarios (< 100 ms total).
2. **Criterio de Cierre:** Pruebas unitarias de concurrencia y flujo de estados en verde en GitHub Actions.
