# Closet Finder

App nativa para iPhone que guarda cada prenda de casa con su foto, talla y medidas, y sobre
todo con el sitio exacto donde está: estancia › mueble › balda, cajón o caja.

- **iPhone y iPad, iOS 17 o posterior.** En iOS 26+ usa Liquid Glass (barra de pestañas flotante, botones
  `.glass`, pestaña de búsqueda del sistema). En iOS 17–25 usa materiales translúcidos
  equivalentes, a través de los modificadores de `DesignSystem/Glass.swift`.
- Swift 6 (aislamiento `MainActor` por defecto), SwiftUI y SwiftData. Sin dependencias externas.
- **Idiomas:** español, inglés, francés, alemán, italiano y portugués (Brasil). Los textos están
  en `Shared/Localizable.xcstrings`; los del Info.plist y de Siri, en `ClosetFinder/InfoPlist.xcstrings`
  y `ClosetFinder/AppShortcuts.xcstrings`. Al compilar en Xcode, los textos nuevos aparecen solos en
  el catálogo para traducirlos. Si el iPhone está en un idioma que la app no tiene, se muestra en
  inglés (`DEVELOPMENT_LANGUAGE = en` en los targets de la app y del widget).

## Funciones

| Pestaña | Qué hace |
| --- | --- |
| Armario | Rejilla de prendas con talla y ubicación, filtros por categoría y favoritas, orden por uso. Selección múltiple para mover o eliminar varias prendas a la vez. **Importar varias fotos** (hasta 50) de una vez. Estadísticas: prendas por categoría y estancia, olvidadas (6 meses sin usar), prestadas y para donar, **valor del armario** (gasto por año y coste por puesta), **tu año en ropa** (se comparte como imagen) y **huecos en el armario** (qué parte les falta a tus looks). |
| Looks | **Probador**: una fila deslizable por cada parte del cuerpo (abrigo, arriba, cuerpo entero, abajo, calzado y accesorios); la prenda centrada es la elegida, la chincheta fija una fila y el dado combina al azar las demás. **Looks**: los guardados, mostrados como una figura vestida; cada uno dice dónde está cada prenda. **Semana**: un look por día, con «Llevar hoy». **Maletas**: viajes con looks y prendas sueltas, y la lista de qué llevar agrupada por dónde está cada prenda, con casillas para ir marcando lo que ya está en la maleta. **«Según la época del viaje»** propone capas (con una prenda tuya para cada una) y looks que encajan, según las fechas y el hemisferio del destino. Cada look se puede **compartir como imagen**. |
| Ubicaciones | Árbol de estancias, muebles y compartimentos con recuento de prendas. Plantillas de mueble (armario con barra, 4 baldas y 2 cajones…). Mover prendas en lote. Etiquetas QR imprimibles y escáner. |
| Medidas | Una o varias personas, medidas corporales y tallas recomendadas (EU/US/UK). En centímetros o pulgadas: por defecto, la unidad de la región (Ajustes › Medidas). |
| Buscar | Texto libre sin acentos ni plurales («chaquetas azules») y filtros como tokens (color, categoría, temporada, estado). En iOS 26 con Apple Intelligence, interpreta frases como «algo de abrigo para la nieve» en el propio iPhone (Foundation Models). Búsquedas recientes y prendas vistas hace poco. |

Además:

- **Primer arranque guiado**: estancias y muebles (con sus cajones y baldas), la primera prenda e
  iCloud. Si el armario llega desde iCloud mientras tanto, se cierra solo.
- **Alta de prendas** con cámara o fototeca. En el dispositivo, Vision recorta el fondo,
  detecta el color dominante y sugiere la categoría. El **modo ráfaga** encadena altas en la
  misma ubicación.
- **Leer la etiqueta**: una foto de la etiqueta interior rellena talla (con EU/UK/US), composición
  e instrucciones de lavado. Reconocimiento de texto de Vision y reglas propias en seis idiomas;
  con Apple Intelligence completa lo que falte.
- **Precio y fecha de compra** de cada prenda, para el valor del armario y el coste por puesta.
- **¿Me queda bien?** Compara las medidas de la prenda en plano con las de su dueño.
- **Spotlight**: las prendas aparecen en la búsqueda del sistema y abren su detalle.
- **Siri / Atajos**: «Busca una prenda en Closet Finder» responde dónde está.
- **Widget configurable** (pequeño y mediano): al editarlo se elige qué mostrar (sin ponerte, look
  de hoy, favoritas, recientes, prestadas, lavando, para donar o una categoría), con
  dónde está cada prenda. Lee el mismo almacén que la app a través del App Group
  `group.com.sergiogonzalez.ClosetFinder`.
- **Apariencia**: automática, clara u oscura (Ajustes, en la pestaña Medidas).
- **iCloud**: sincronización con la base de datos privada del usuario. Si se borra la app y se
  vuelve a instalar con el mismo Apple ID, los datos vuelven solos. Sin iCloud, se puede exportar
  y restaurar una copia de seguridad (`.closetfinder`) desde Ajustes (pestaña Medidas).
- **Enlaces `closetfinder://`**: `closetfinder://garment/<uuid>` y `closetfinder://location/<uuid>`.
  Los usan el widget y las etiquetas QR, que también se pueden escanear con la Cámara del sistema.

## Ejecutar

Abre `ClosetFinder.xcodeproj` en Xcode 26 o posterior y ejecuta el esquema **ClosetFinder**.

- Para empezar con un armario de ejemplo, pulsa «Probar con un armario de ejemplo» en la
  pestaña Armario, o añade el argumento de arranque `-seedSampleData`.
- `-inMemoryStore` arranca con un almacén temporal que no se guarda.
- Solo en Debug: `-openTab locations|profile|search|stats`, `-openGarment "<nombre>"`,
  `-openLocation "<nombre>"` y `-search "<texto>"` abren una pantalla concreta al arrancar.
- `-showOnboarding` enseña el primer arranque aunque ya se haya visto; `-skipOnboarding` lo salta.
- Solo en Debug: `-samplePhotos` da a las prendas de ejemplo una foto recortada (su ilustración);
  `-openTab looks|outfits|week|trips`, `-openOutfit "<nombre>"` y `-openTrip "<nombre>"` abren los
  looks; `-selecting` abre el Armario en modo selección.
- En el simulador no funcionan el recorte de fondo de Vision, el escáner QR ni la generación de
  Apple Intelligence: hay que probarlos en un iPhone real.
- La firma usa el equipo `84HB28K4CM` (iCloud y App Group). Para sincronizar de verdad hay que
  ejecutar una vez desde Xcode en un dispositivo para que se cree el contenedor
  `iCloud.com.sergiogonzalez.ClosetFinder`.

Textos nuevos desde la línea de comandos: `python3 scripts/update_strings.py <DerivedData> [nuevas.json]`
añade al catálogo las claves que extrae el compilador y comprueba que estén en los seis idiomas.

Tests (Swift Testing). También se ejecutan en GitHub Actions en cada pull request y en cada push a `main` (`.github/workflows/ci.yml`):

```bash
xcodebuild test -project ClosetFinder.xcodeproj -scheme ClosetFinder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Estructura

```
ClosetFinder/          App
├─ App/                Punto de entrada, pestañas, navegación y enlaces
├─ Features/           Closet · Looks · AddGarment · Locations · Search · Profile · Settings · Onboarding
├─ Services/           ImageProcessor (Vision), GarmentSearch, SmartSearch (Foundation Models),
│                      Spotlight, BackupService, LabelReader, WardrobeValue, PackingAdvisor,
│                      TripPlace (MapKit), RecentHistory
├─ Intents/            App Intents para Siri y Atajos
└─ DesignSystem/       Botones, cristal con alternativa para iOS < 26 y componentes
Shared/                Código común a la app y al widget
├─ Models/             Garment, StorageLocation, BodyProfile, Outfit, OutfitPlan, Trip (SwiftData)
├─ Services/           SizeConverter, LengthUnit, WardrobeInsights, DeepLink
└─ DesignSystem/       Ilustraciones de prendas y color de marca
ClosetFinderWidget/    Widget configurable (WidgetKit + App Intents)
```

## Pendiente (hoja de ruta)

- Publicación en el App Store (App Store Connect, capturas, ficha y política de privacidad).
- Auditoría de accesibilidad con VoiceOver y tamaños de texto grandes.
- Etiquetas NFC en cajas y cajones.
