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
| Armario | Rejilla de prendas con talla y ubicación, filtros por categoría y favoritas, orden por uso. Estadísticas: prendas por categoría y estancia, olvidadas (6 meses sin usar), prestadas y para donar. |
| Ubicaciones | Árbol de estancias, muebles y compartimentos con recuento de prendas. Plantillas de mueble (armario con barra, 4 baldas y 2 cajones…). Mover prendas en lote. Etiquetas QR imprimibles y escáner. |
| Medidas | Una o varias personas, medidas corporales y tallas recomendadas (EU/US/UK). |
| Buscar | Texto libre sin acentos ni plurales («chaquetas azules») y filtros como tokens (color, categoría, temporada, estado). En iOS 26 con Apple Intelligence, interpreta frases como «algo de abrigo para la nieve» en el propio iPhone (Foundation Models). |

Además:

- **Alta de prendas** con cámara o fototeca. En el dispositivo, Vision recorta el fondo,
  detecta el color dominante y sugiere la categoría. El **modo ráfaga** encadena altas en la
  misma ubicación.
- **¿Me queda bien?** Compara las medidas de la prenda en plano con las de su dueño.
- **Spotlight**: las prendas aparecen en la búsqueda del sistema y abren su detalle.
- **Siri / Atajos**: «Busca una prenda en Closet Finder» responde dónde está.
- **Widget «Sin ponerte»** (pequeño y mediano): las prendas que llevas más tiempo sin usar y
  dónde están. Lee el mismo almacén que la app a través del App Group
  `group.com.sergiogonzalez.ClosetFinder`.
- **Enlaces `closetfinder://`**: `closetfinder://garment/<uuid>` y `closetfinder://location/<uuid>`.
  Los usan el widget y las etiquetas QR, que también se pueden escanear con la Cámara del sistema.

## Ejecutar

Abre `ClosetFinder.xcodeproj` en Xcode 26 o posterior y ejecuta el esquema **ClosetFinder**.

- Para empezar con un armario de ejemplo, pulsa «Probar con un armario de ejemplo» en la
  pestaña Armario, o añade el argumento de arranque `-seedSampleData`.
- `-inMemoryStore` arranca con un almacén temporal que no se guarda.
- Solo en Debug: `-openTab locations|profile|search|stats`, `-openGarment "<nombre>"`,
  `-openLocation "<nombre>"` y `-search "<texto>"` abren una pantalla concreta al arrancar.
- En el simulador no funcionan el recorte de fondo de Vision, el escáner QR ni la generación
  de Apple Intelligence: hay que probarlos en un iPhone real.

Tests (Swift Testing). También se ejecutan en GitHub Actions en cada pull request y en cada push a `main` (`.github/workflows/ci.yml`):

```bash
xcodebuild test -project ClosetFinder.xcodeproj -scheme ClosetFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Estructura

```
ClosetFinder/          App
├─ App/                Punto de entrada, pestañas, navegación y enlaces
├─ Features/           Closet · AddGarment · Locations · Search · Profile
├─ Services/           ImageProcessor (Vision), GarmentSearch, SmartSearch (Foundation Models), Spotlight
├─ Intents/            App Intents para Siri y Atajos
└─ DesignSystem/       Cristal con alternativa para iOS < 26 y componentes
Shared/                Código común a la app y al widget
├─ Models/             Garment, StorageLocation, BodyProfile (SwiftData), enumeraciones y almacén
├─ Services/           SizeConverter, WardrobeInsights, DeepLink
└─ DesignSystem/       Ilustraciones de prendas y color de marca
ClosetFinderWidget/    Widget «Sin ponerte» (WidgetKit)
```

## Pendiente (hoja de ruta)

- **Sincronización con iCloud.** El modelo ya cumple los requisitos de CloudKit. Falta añadir la
  capacidad iCloud al target y pasar `cloudKitDatabase` a `.automatic` en `AppModelContainer`.
- Auditoría de accesibilidad (VoiceOver, Dynamic Type) y traducción al inglés.
- Publicación en el App Store.
- **Probador virtual.** Ver cómo te queda una prenda a partir de una foto tuya. Las fotos ya se
  guardan recortadas y con transparencia (hasta 1600 px), que es la entrada que necesita.
