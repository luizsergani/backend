#!/bin/bash
# Compila o Sussurro e monta o .app em dist/Sussurro.app
set -euo pipefail
cd "$(dirname "$0")"

echo "Compilando..."
swift build -c release

APP="dist/Sussurro.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Sussurro "$APP/Contents/MacOS/Sussurro"
cp Info.plist "$APP/Contents/Info.plist"

# assinatura ad-hoc para o macOS lembrar das permissões (mic/acessibilidade)
codesign --force --sign - "$APP"

echo
echo "✅ App gerado em: $PWD/$APP"
echo "Para instalar:  cp -R \"$APP\" /Applications/ && open /Applications/Sussurro.app"
