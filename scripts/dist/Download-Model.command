#!/bin/bash
# Downloads the Whisper speech model MyWhisper uses (one-time, ~1.5 GB).
set -e
DIR="$HOME/Library/Application Support/MyWhisper/models"
FILE="ggml-large-v3-turbo.bin"
mkdir -p "$DIR"
if [ -f "$DIR/$FILE" ]; then
  echo "Model already installed — you're good to go."
  read -p "Press Enter to close."
  exit 0
fi
echo "Downloading Whisper large-v3-turbo (about 1.5 GB, one time only)…"
echo "Supports ~100 languages. Everything runs offline after this download."
curl -L --fail -C - --progress-bar -o "$DIR/$FILE.part" \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$FILE"
mv "$DIR/$FILE.part" "$DIR/$FILE"
echo
echo "Done! Now open MyWhisper.app and press Option+Space to dictate."
read -p "Press Enter to close."
