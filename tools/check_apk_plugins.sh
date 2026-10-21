#!/usr/bin/env bash
# Vérifie que chaque plugin Android enregistré au démarrage a bien été compilé dans l'APK.
# Un plugin absent fait échouer l'enregistrement de tous les plugins : l'app reste alors
# bloquée sur l'écran de démarrage. Usage : tools/check_apk_plugins.sh <variante>  (ex. devRelease)
set -euo pipefail

variant="$1"
registrant=android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
mapping="build/app/outputs/mapping/$variant/mapping.txt"

[ -f "$registrant" ] || { echo "::error::$registrant introuvable"; exit 1; }
[ -f "$mapping" ] || { echo "::error::$mapping introuvable"; exit 1; }

plugins=$(sed -n 's/.*\.add(new \([A-Za-z0-9_.$]*\)());.*/\1/p' "$registrant")
[ -n "$plugins" ] || { echo "::error::Aucun plugin trouvé dans $registrant"; exit 1; }

missing=0
for plugin in $plugins; do
  if grep -q "^${plugin//./\\.} -> " "$mapping"; then
    echo "OK       $plugin"
  else
    echo "::error::Plugin absent de l'APK : $plugin"
    missing=1
  fi
done
exit "$missing"
