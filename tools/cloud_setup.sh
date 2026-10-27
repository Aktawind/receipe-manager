#!/usr/bin/env bash
# Installe Flutter et le SDK Android dans un environnement cloud Claude Code.
# Idempotent : ne fait rien si tout est déjà en place.
set -euo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK=/opt/sdk
FLUTTER_VERSION="$(sed -n 's/^  flutter: *\([0-9.]*\)$/\1/p' "$ROOT/pubspec.yaml")"

mkdir -p "$SDK"
if [ ! -x "$SDK/flutter/bin/flutter" ]; then
  curl -sSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$SDK"
fi
if [ ! -d "$SDK/android/cmdline-tools/latest" ]; then
  tmp="$(mktemp -d)"
  curl -sSL -o "$tmp/clt.zip" https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
  mkdir -p "$SDK/android/cmdline-tools"
  unzip -q "$tmp/clt.zip" -d "$SDK/android/cmdline-tools"
  mv "$SDK/android/cmdline-tools/cmdline-tools" "$SDK/android/cmdline-tools/latest"
  rm -rf "$tmp"
  yes | "$SDK/android/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
fi

git config --global --add safe.directory '*'
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export ANDROID_HOME=$SDK/android"
    echo "export PATH=$SDK/flutter/bin:$SDK/android/cmdline-tools/latest/bin:\$PATH"
  } >> "$CLAUDE_ENV_FILE"
fi

export PATH="$SDK/flutter/bin:$PATH"
flutter --disable-analytics >/dev/null 2>&1 || true
(cd "$ROOT" && flutter pub get >/dev/null 2>&1) || true
