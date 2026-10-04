#!/usr/bin/env python3
"""Actualiza Shared/Localizable.xcstrings desde la línea de comandos.

Xcode añade los textos nuevos al catálogo al compilar desde el IDE; con `xcodebuild` no. Este
script hace lo mismo y además rellena traducciones:

1. Lee las claves que extrae el compilador (ficheros .stringsdata de una compilación).
2. Conserva las traducciones que ya hay en el catálogo.
3. Añade las de un JSON opcional: {"clave": {"en": "...", "fr": "...", ...}}.
4. Comprueba que cada clave está en todos los idiomas y que los marcadores (%@, %lld…)
   coinciden con el texto original. Si falta algo, lo lista y termina con error.

Uso:
    xcodebuild build ... -derivedDataPath /tmp/DD
    python3 scripts/update_strings.py /tmp/DD [nuevas.json]
"""
import collections
import glob
import json
import re
import sys

CATALOG = "Shared/Localizable.xcstrings"
LANGUAGES = ["en", "fr", "de", "it", "pt-BR"]
SPECIFIER = re.compile(r"%(?:\d+\$)?(@|lld|ld|d|f)")


def signature(text):
    return sorted(SPECIFIER.findall(text))


def main():
    derived = sys.argv[1]
    additions = json.load(open(sys.argv[2])) if len(sys.argv) > 2 else {}

    keys = collections.OrderedDict()
    for path in sorted(glob.glob(f"{derived}/**/*.stringsdata", recursive=True)):
        for entry in json.load(open(path)).get("tables", {}).get("Localizable", []):
            keys.setdefault(entry["key"], entry.get("value"))

    existing = json.load(open(CATALOG))["strings"]
    strings, missing, wrong = collections.OrderedDict(), [], []
    for key in sorted(keys, key=str.lower):
        source = keys[key] or key
        known = {lang: unit["stringUnit"]["value"]
                 for lang, unit in existing.get(key, {}).get("localizations", {}).items()}
        known.update(additions.get(key, {}))
        entry = {"localizations": {}}
        if keys[key]:
            entry["localizations"]["es"] = {"stringUnit": {"state": "translated", "value": keys[key]}}
        for lang in LANGUAGES:
            if lang not in known:
                missing.append(key)
                break
            # El género gramatical («m», «f», «n») no lleva marcadores.
            if not key.startswith("category.gender") and signature(known[lang]) != signature(source):
                wrong.append((key, lang, known[lang]))
            entry["localizations"][lang] = {"stringUnit": {"state": "translated", "value": known[lang]}}
        strings[key] = entry

    if missing or wrong:
        for key in missing:
            print("Falta traducir:", json.dumps(key, ensure_ascii=False))
        for key, lang, value in wrong:
            print(f"Marcadores distintos en {lang}:", json.dumps(key, ensure_ascii=False), "→", value)
        sys.exit(1)

    json.dump({"sourceLanguage": "es", "strings": strings, "version": "1.0"},
              open(CATALOG, "w"), ensure_ascii=False, indent=2)
    print(f"{len(strings)} claves en {CATALOG}")


if __name__ == "__main__":
    main()
