#!/usr/bin/env bash
# Installe l'APK sur un émulateur, lance l'app et vérifie qu'elle affiche son premier écran
# sans erreur de démarrage (repères écrits par lib/main.dart dans logcat).
# Usage : tools/smoke_test.sh <apk> <package>
set -euo pipefail

apk="$1"
package="$2"

adb install -r "$apk"
adb logcat -c
adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null

for _ in $(seq 1 60); do
  log="$(adb logcat -d -s flutter:I)"
  if grep -q "RECETTES_STARTUP_FAILED" <<<"$log"; then
    echo "::error::L'application affiche une erreur au démarrage"
    adb logcat -d | tail -200
    exit 1
  fi
  if grep -q "RECETTES_STARTUP_OK" <<<"$log"; then
    echo "Démarrage OK"
    exit 0
  fi
  sleep 2
done

echo "::error::Aucun écran affiché après 120 s (application bloquée au démarrage ?)"
adb logcat -d | tail -300
exit 1
