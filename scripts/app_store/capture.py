#!/usr/bin/env python3
"""Hace las capturas en bruto para el App Store con el armario de ejemplo.

Para cada dispositivo, idioma y pantalla arranca la app en el simulador con los argumentos de
depuración que abren esa pantalla, y guarda la captura en `fastlane/screenshots_raw/`.
Después, `frame.swift` les pone el titular y el fondo.

Uso:
    xcodebuild build -scheme ClosetFinder -destination 'generic/platform=iOS Simulator' -derivedDataPath DD
    python3 scripts/app_store/capture.py DD/Build/Products/Debug-iphonesimulator/ClosetFinder.app \
        [--devices iphone,ipad] [--locales es-ES,en-US] [--screens 01,02]
"""
import argparse
import json
import os
import subprocess
import time

BUNDLE = "com.sergiogonzalez.ClosetFinder"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, "Shared", "Localizable.xcstrings")
OUTPUT = os.path.join(ROOT, "fastlane", "screenshots_raw")

# Simuladores con el tamaño que pide el App Store: iPhone de 6,9" y iPad de 13".
DEVICES = {
    "iphone": "iPhone 17 Pro Max",
    "ipad": "iPad Pro 13-inch (M5)",
}

# Idioma del App Store → idioma y región de la app.
LOCALES = {
    "es-ES": ("es", "es_ES"),
    "en-US": ("en", "en_US"),
    "fr-FR": ("fr", "fr_FR"),
    "de-DE": ("de", "de_DE"),
    "it": ("it", "it_IT"),
    "pt-BR": ("pt-BR", "pt_BR"),
}

# Pantallas, en el orden en que salen en la tienda. Los nombres entre llaves se traducen con el
# catálogo, porque los datos de ejemplo están en el idioma de la app.
SCREENS = [
    ("01-armario", []),
    ("02-prenda", ["-openGarment", "{Chaqueta vaquera}"]),
    ("03-ubicacion", ["-openLocation", "{Armario grande}"]),
    ("04-probador", ["-openTab", "looks"]),
    ("05-semana", ["-openTab", "week"]),
    ("06-maleta", ["-openTrip", "{Escapada a la sierra}"]),
    ("07-buscar", ["-openTab", "search", "-search", "{color.blue.feminine}"]),
    ("08-importar", ["-openImportDemo"]),
    ("09-medidas", ["-openTab", "profile"]),
    ("10-valor", ["-openTab", "value"]),
]


def translate(key, language):
    """El texto de la clave en ese idioma. En español, la clave es el propio texto salvo en las
    claves explícitas («color.blue.feminine»), que tienen su valor en el catálogo."""
    entry = json.load(open(CATALOG))["strings"].get(key, {})
    value = entry.get("localizations", {}).get(language, {}).get("stringUnit", {}).get("value")
    return value if value is not None else key


def simctl(*args, check=True):
    return subprocess.run(["xcrun", "simctl", *args], check=check, capture_output=True, text=True)


def udid(name):
    devices = json.loads(simctl("list", "devices", "available", "-j").stdout)["devices"]
    for runtime in sorted(devices, reverse=True):
        for device in devices[runtime]:
            if device["name"] == name:
                return device["udid"]
    raise SystemExit(f"No hay ningún simulador «{name}»")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("app")
    parser.add_argument("--devices", default=",".join(DEVICES))
    parser.add_argument("--locales", default=",".join(LOCALES))
    parser.add_argument("--screens", default="")
    parser.add_argument("--wait", type=float, default=4.5)
    options = parser.parse_args()
    wanted = [s for s in options.screens.split(",") if s]

    for device in options.devices.split(","):
        identifier = udid(DEVICES[device])
        simctl("boot", identifier, check=False)
        simctl("bootstatus", identifier, "-b")
        simctl("status_bar", identifier, "override", "--time", "9:41", "--dataNetwork", "wifi", "--wifiBars", "3",
               "--cellularBars", "4", "--batteryState", "discharging", "--batteryLevel", "100")
        simctl("ui", identifier, "appearance", "light")
        simctl("install", identifier, options.app)
        for store_locale in options.locales.split(","):
            language, region = LOCALES[store_locale]
            folder = os.path.join(OUTPUT, store_locale)
            os.makedirs(folder, exist_ok=True)
            for name, extra in SCREENS:
                if wanted and name[:2] not in wanted:
                    continue
                arguments = [translate(a[1:-1], language) if a.startswith("{") else a for a in extra]
                simctl("terminate", identifier, BUNDLE, check=False)
                simctl("launch", identifier, BUNDLE, "-inMemoryStore", "-seedSampleData", "-skipOnboarding",
                       "-AppleLanguages", f"({language})", "-AppleLocale", region, *arguments)
                time.sleep(options.wait)
                path = os.path.join(folder, f"{device}-{name}.png")
                simctl("io", identifier, "screenshot", path)
                print(path)
        simctl("terminate", identifier, BUNDLE, check=False)
        simctl("status_bar", identifier, "clear", check=False)


if __name__ == "__main__":
    main()
