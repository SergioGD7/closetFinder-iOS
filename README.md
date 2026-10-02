# Closet Finder

App nativa para iPhone que guarda cada prenda de casa con su foto, talla y medidas, y sobre
todo con el sitio exacto donde está: estancia › mueble › balda, cajón o caja.

- **iOS 17 o posterior.** En iOS 26+ usa Liquid Glass (barra de pestañas flotante, botones
  `.glass`, pestaña de búsqueda del sistema). En iOS 17–25 usa materiales translúcidos
  equivalentes, a través de los modificadores de `DesignSystem/Glass.swift`.
- Swift 6 (aislamiento `MainActor` por defecto), SwiftUI y SwiftData. Sin dependencias externas.

## Funciones

| Pestaña | Qué hace |
| --- | --- |
| Armario | Rejilla de prendas con talla y ubicación, filtros por categoría y favoritas, orden por uso. |
| Ubicaciones | Árbol de estancias, muebles y compartimentos con recuento de prendas. Plantillas de mueble (armario con barra, 4 baldas y 2 cajones…). Mover prendas en lote. |
| Medidas | Una o varias personas, medidas corporales y tallas recomendadas (EU/US/UK). |
| Buscar | Texto libre sin acentos ni plurales («chaquetas azules») y filtros como tokens (color, categoría, temporada, estado). |

Además:

- **Alta de prendas** con cámara o fototeca. En el dispositivo, Vision recorta el fondo,
  detecta el color dominante y sugiere la categoría. El **modo ráfaga** encadena altas en la
  misma ubicación.
- **¿Me queda bien?** Compara las medidas de la prenda en plano con las de su dueño.
- **Spotlight**: las prendas aparecen en la búsqueda del sistema y abren su detalle.
- **Siri / Atajos**: «Busca una prenda en Closet Finder» responde dónde está.

## Ejecutar

Abre `ClosetFinder.xcodeproj` en Xcode 26 o posterior y ejecuta el esquema **ClosetFinder**.

- Para empezar con un armario de ejemplo, pulsa «Probar con un armario de ejemplo» en la
  pestaña Armario, o añade el argumento de arranque `-seedSampleData`.
- `-inMemoryStore` arranca con un almacén temporal que no se guarda.
- El recorte de fondo de Vision no funciona en el simulador: ahí la foto se guarda tal cual.

Tests (Swift Testing). También se ejecutan en GitHub Actions en cada pull request y en cada push a `main` (`.github/workflows/ci.yml`):

```bash
xcodebuild test -project ClosetFinder.xcodeproj -scheme ClosetFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Estructura

```
ClosetFinder/
├─ App/            Punto de entrada, pestañas y navegación
├─ Models/         Garment, StorageLocation, BodyProfile (SwiftData) y enumeraciones
├─ Features/       Closet · AddGarment · Locations · Search · Profile
├─ Services/       ImageProcessor (Vision), GarmentSearch, SizeConverter, SpotlightIndexer
├─ Intents/        App Intents para Siri y Atajos
└─ DesignSystem/   Cristal con alternativa para iOS < 26, ilustraciones y componentes
```

## Pendiente (hoja de ruta)

- **Sincronización con iCloud.** El modelo ya cumple los requisitos de CloudKit. Falta añadir la
  capacidad iCloud al target y pasar `cloudKitDatabase` a `.automatic` en `AppModelContainer`.
- Etiquetas QR imprimibles para cajas, widget y estadísticas de uso.
- **Probador virtual.** Ver cómo te queda una prenda a partir de una foto tuya. Las fotos ya se
  guardan recortadas y con transparencia (hasta 1600 px), que es la entrada que necesita.
