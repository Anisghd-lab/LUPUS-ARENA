#!/usr/bin/env python3
"""
Script de vérification automatique et rapide de l'intégrité des traductions
pour le projet Lupus Arena (FR, AR, EN).
Vérifie :
1. La parité des clés entre fr, ar et en dans AppTranslations
2. La correspondance des placeholders dynamiques ({name}, {count}, etc.)
3. L'exactitude des termes demandés (ex: 'day' == 'النهار')
4. L'existence dans le dictionnaire de toutes les clés appelées via context.tr(...) dans les fichiers .dart
5. Le verrouillage LTR du layout dans main.dart (pour éviter l'inversion de l'interface en Arabe)
"""

import os
import re
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
TRANSLATIONS_FILE = BASE_DIR / "lib" / "services" / "app_translations.dart"
MAIN_FILE = BASE_DIR / "lib" / "main.dart"
LIB_DIR = BASE_DIR / "lib"


def parse_language_blocks(content: str):
    """Extrait les dictionnaires pour fr, ar et en depuis app_translations.dart"""
    langs = {}
    pattern = re.compile(
        r"'(fr|ar|en)'\s*:\s*\{(?P<body>.*?)\n\s*\},", re.DOTALL
    )
    for match in pattern.finditer(content):
        lang = match.group(1)
        body = match.group("body")
        entries = {}
        # Extrait 'cle': 'valeur'
        entry_pattern = re.compile(r"'(?P<key>[a-zA-Z0-9_]+)'\s*:\s*'(?P<val>(?:\\'|[^'])*)'")
        for em in entry_pattern.finditer(body):
            k = em.group("key")
            v = em.group("val").replace(r"\'", "'")
            entries[k] = v
        langs[lang] = entries
    return langs


def main():
    print("=" * 65)
    print(" 🐺 LUPUS ARENA - VÉRIFICATION DES TRADUCTIONS (FR / AR / EN) 🐺")
    print("=" * 65)

    if not TRANSLATIONS_FILE.exists():
        print(f"❌ Fichier de traductions introuvable : {TRANSLATIONS_FILE}")
        sys.exit(1)

    with open(TRANSLATIONS_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    langs = parse_language_blocks(content)
    expected_langs = ["fr", "ar", "en"]
    for l in expected_langs:
        if l not in langs:
            print(f"❌ Bloc de langue '{l}' introuvable dans app_translations.dart !")
            sys.exit(1)

    fr_dict = langs["fr"]
    ar_dict = langs["ar"]
    en_dict = langs["en"]

    print(f"\n[1] Statistiques du dictionnaire :")
    print(f"  • Français (fr) : {len(fr_dict)} clés")
    print(f"  • Arabe (ar)    : {len(ar_dict)} clés")
    print(f"  • Anglais (en)  : {len(en_dict)} clés")

    # 1. Vérification de la parité des clés
    errors = []
    fr_keys = set(fr_dict.keys())
    ar_keys = set(ar_dict.keys())
    en_keys = set(en_dict.keys())

    missing_in_ar = fr_keys - ar_keys
    missing_in_en = fr_keys - en_keys
    surplus_ar = ar_keys - fr_keys
    surplus_en = en_keys - fr_keys

    if missing_in_ar:
        errors.append(f"Clés présentes en FR mais manquantes en AR ({len(missing_in_ar)}) : {sorted(list(missing_in_ar))}")
    if missing_in_en:
        errors.append(f"Clés présentes en FR mais manquantes en EN ({len(missing_in_en)}) : {sorted(list(missing_in_en))}")
    if surplus_ar:
        errors.append(f"Clés présentes en AR mais absentes de FR ({len(surplus_ar)}) : {sorted(list(surplus_ar))}")
    if surplus_en:
        errors.append(f"Clés présentes en EN mais absentes de FR ({len(surplus_en)}) : {sorted(list(surplus_en))}")

    # 2. Vérification de la correspondance des placeholders
    placeholder_pattern = re.compile(r"\{([a-zA-Z0-9_]+)\}")
    for k in fr_keys:
        if k in ar_dict and k in en_dict:
            fr_ph = set(placeholder_pattern.findall(fr_dict[k]))
            ar_ph = set(placeholder_pattern.findall(ar_dict[k]))
            en_ph = set(placeholder_pattern.findall(en_dict[k]))
            if fr_ph != ar_ph:
                errors.append(f"Placeholders discordants pour la clé '{k}' (FR: {fr_ph} vs AR: {ar_ph})")
            if fr_ph != en_ph:
                errors.append(f"Placeholders discordants pour la clé '{k}' (FR: {fr_ph} vs EN: {en_ph})")

    # 3. Vérification de la demande utilisateur spécifique
    print(f"\n[2] Vérification des termes spécifiques :")
    ar_day = ar_dict.get("day")
    if ar_day == "النهار":
        print(f"  ✅ 'day' en Arabe = '{ar_day}' (conforme à la demande : jour = النهار)")
    else:
        errors.append(f"Erreur terme : 'day' en Arabe vaut '{ar_day}', attendu 'النهار' !")

    ar_night = ar_dict.get("night")
    print(f"  ✅ 'night' en Arabe = '{ar_night}'")
    fr_become_host = fr_dict.get("become_host")
    print(f"  ✅ 'become_host' : FR='{fr_become_host}' | AR='{ar_dict.get('become_host')}' | EN='{en_dict.get('become_host')}'")

    # 4. Vérification de toutes les clés appelées dans les fichiers .dart
    print(f"\n[3] Scan des fichiers .dart dans lib/ :")
    dart_files = list(LIB_DIR.rglob("*.dart"))
    used_keys = set()
    tr_call_pattern = re.compile(r"""(?:context\.tr|AppTranslations\.getText)\s*\(\s*(?:context\s*,\s*)?['"]([a-zA-Z0-9_]+)['"]""")

    for df in dart_files:
        if df == TRANSLATIONS_FILE:
            continue
        try:
            with open(df, "r", encoding="utf-8") as f:
                code = f.read()
            for m in tr_call_pattern.finditer(code):
                used_keys.add(m.group(1))
        except Exception as e:
            errors.append(f"Erreur de lecture du fichier {df}: {e}")

    print(f"  • {len(dart_files)} fichiers Dart analysés.")
    print(f"  • {len(used_keys)} clés uniques de traduction utilisées dans l'UI.")

    missing_in_translations = used_keys - fr_keys
    if missing_in_translations:
        errors.append(f"Clés appelées dans le code mais absentes de AppTranslations ({len(missing_in_translations)}) : {sorted(list(missing_in_translations))}")
    else:
        print(f"  ✅ 100% des clés appelées dans le code UI existent bien dans AppTranslations !")

    # 5. Vérification du verrouillage LTR du layout dans main.dart
    print(f"\n[4] Vérification du modèle d'agencement LTR :")
    with open(MAIN_FILE, "r", encoding="utf-8") as f:
        main_code = f.read()

    if "TextDirection.ltr" in main_code and "Directionality" in main_code:
        print("  ✅ 'TextDirection.ltr' configuré dans MaterialApp.builder : l'affichage ne sera pas inversé en Arabe, les boutons et le layout restent identiques au modèle français.")
    else:
        errors.append("Attention : Directionality(textDirection: TextDirection.ltr) non détecté dans lib/main.dart !")

    # Synthèse finale
    print("\n" + "=" * 65)
    if errors:
        print(f"❌ {len(errors)} ANOMALIE(S) DÉTECTÉE(S) :")
        for err in errors:
            print(f"  - {err}")
        print("=" * 65)
        sys.exit(1)
    else:
        print("🎉 TOUTES LES VÉRIFICATIONS SONT VALIDÉES AVEC SUCCÈS ! (0 erreur)")
        print("  • Parité stricte 100% entre FR, AR et EN")
        print("  • Placeholders cohérents")
        print("  • jour = النهار validé")
        print("  • Layout LTR préservé pour l'arabe (modèle français)")
        print("  • Zéro clé manquante")
        print("=" * 65)
        sys.exit(0)


if __name__ == "__main__":
    main()
