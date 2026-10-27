#!/usr/bin/env bash
# Installe l'APK sur un émulateur, lance l'app et vérifie qu'elle affiche son premier écran
# sans erreur de démarrage (repères écrits par lib/main.dart dans logcat).
# Usage : tools/smoke_test.sh <apk> <package>
set -euo pipefail

apk="$1"
package="$2"

# Logs utiles au diagnostic : messages Flutter, plantages, et tout ce qui vient du processus de l'app.
dump_app_logs() {
  echo "----- flutter / AndroidRuntime -----"
  adb logcat -d -s flutter:V AndroidRuntime:E DEBUG:V | tail -150
  local pid
  pid="$(adb shell pidof "$package" | tr -d '\r' || true)"
  if [ -n "$pid" ]; then
    echo "----- processus $package (pid $pid) -----"
    adb logcat -d --pid="$pid" | tail -150
  fi
}

adb install -r "$apk"
adb logcat -c
adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null

for _ in $(seq 1 60); do
  log="$(adb logcat -d -s flutter:I)"
  if grep -q "RECETTES_STARTUP_FAILED" <<<"$log"; then
    echo "::error::L'application affiche une erreur au démarrage"
    echo "$log"
    dump_app_logs
    exit 1
  fi
  if grep -q "RECETTES_STARTUP_OK" <<<"$log"; then
    echo "Démarrage OK"
    exit 0
  fi
  sleep 2
done

echo "::error::Aucun écran affiché après 120 s (application bloquée au démarrage ?)"
dump_app_logs
exit 1
