# Publicación en el App Store

Todo lo que hace falta para la ficha de Closet Finder en App Store Connect, en los seis
idiomas de la app: español (es-ES), inglés (en-US), francés (fr-FR), alemán (de-DE), italiano (it)
y portugués de Brasil (pt-BR). La estructura es la de `fastlane deliver`.

## Ficha (`metadata/`)

| Archivo | Límite | Qué es |
| --- | --- | --- |
| `name.txt` | 30 | Nombre: «Closet Finder» en todos los idiomas |
| `subtitle.txt` | 30 | Subtítulo bajo el nombre |
| `promotional_text.txt` | 170 | Texto promocional (se puede cambiar sin nueva versión) |
| `description.txt` | 4000 | Descripción completa |
| `keywords.txt` | 100 | Palabras clave separadas por comas, sin repetir las del nombre |
| `privacy_url.txt`, `support_url.txt` | | Política de privacidad y soporte, en el idioma de la ficha |
| `copyright.txt`, `primary_category.txt`, `secondary_category.txt` | | Comunes: © 2026, Estilo de vida y Productividad |

Los textos se generan con `python3 scripts/app_store/metadata.py`, que comprueba los límites.
Para cambiar algo, edita ese script y vuelve a ejecutarlo.

## Capturas (`screenshots/`)

Diez capturas por idioma en iPhone de 6,9" (1320 × 2868) y en iPad de 13" (2064 × 2752), con
el armario de ejemplo:

1. Armario · 2. Detalle de prenda y dónde está · 3. Mueble con sus compartimentos ·
4. Probador · 5. Semana · 6. Maleta · 7. Buscar · 8. Importar fotos · 9. Medidas y tallas ·
10. Valor del armario

No se guardan en git (pesan mucho). Para generarlas:

```bash
scripts/app_store/make_screenshots.sh
```

Tarda unos 15 minutos. Se puede limitar con `--locales es-ES,en-US`, `--devices iphone` o
`--screens 01,04`. Los titulares de cada captura están en `scripts/app_store/captions.json`.

## Subir a App Store Connect

Con [fastlane](https://fastlane.tools) instalado y la app creada en App Store Connect:

```bash
fastlane deliver --skip_binary_upload --app_identifier com.sergiogonzalez.ClosetFinder
```

También se pueden copiar los textos y arrastrar las capturas a mano en App Store Connect.

## Lo que hay que rellenar en App Store Connect

- **URL de privacidad** y **URL de soporte**: ya están en `privacy_url.txt` y `support_url.txt` de
  cada idioma. Son páginas de GitHub Pages (carpeta `docs/`), generadas con
  `python3 scripts/app_store/web.py`:
  - https://sergiogd7.github.io/closetFinder-iOS/privacy/
  - https://sergiogd7.github.io/closetFinder-iOS/support/
- **Privacidad de la app**: «No se recopilan datos». La app no tiene analítica, anuncios ni
  cuentas; los datos están en el dispositivo y en el iCloud privado del usuario.
- **Clasificación por edades**: 4+ (ningún contenido sensible).
- **Cifrado**: la app no usa cifrado propio; la respuesta es «No» (solo el cifrado estándar del sistema).
