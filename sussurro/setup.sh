#!/bin/bash
# Setup completo do Sussurro: instala o whisper.cpp, baixa o modelo e compila o app.
#
# Uso:
#   ./setup.sh                  # modelo padrão (large-v3-turbo, ~1.6 GB — melhor qualidade)
#   ./setup.sh small            # modelo pequeno (~500 MB — mais rápido, qualidade menor)
#   ./setup.sh medium           # meio-termo (~1.5 GB)
set -euo pipefail
cd "$(dirname "$0")"

MODEL="${1:-large-v3-turbo}"
MODELS_DIR="$HOME/Library/Application Support/Sussurro/models"
MODEL_FILE="$MODELS_DIR/ggml-$MODEL.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$MODEL.bin"

if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew não encontrado. Instale primeiro: https://brew.sh"
    exit 1
fi

if ! command -v whisper-cli >/dev/null 2>&1 && ! brew list whisper-cpp >/dev/null 2>&1; then
    echo "Instalando whisper.cpp via Homebrew..."
    brew install whisper-cpp
else
    echo "✓ whisper.cpp já instalado"
fi

mkdir -p "$MODELS_DIR"
if [ -f "$MODEL_FILE" ]; then
    echo "✓ Modelo $MODEL já baixado"
else
    echo "Baixando o modelo $MODEL (pode demorar um pouco)..."
    curl -L --fail --progress-bar -o "$MODEL_FILE.tmp" "$MODEL_URL"
    mv "$MODEL_FILE.tmp" "$MODEL_FILE"
    echo "✓ Modelo salvo em $MODEL_FILE"
fi

./build.sh

echo
echo "🎙️  Tudo pronto! Agora:"
echo "   1. cp -R dist/Sussurro.app /Applications/"
echo "   2. open /Applications/Sussurro.app"
echo "   3. Autorize o Microfone e a Acessibilidade quando o macOS pedir."
echo "   4. Clique no ícone 🎤 na barra de menu (ou ⌥⌘D) para gravar."
