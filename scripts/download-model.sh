#!/usr/bin/env bash
# Download a whisper.cpp ggml model into MyWhisper's models folder.
set -euo pipefail

MODEL="${1:-large-v3-turbo}"
DIR="$HOME/Library/Application Support/MyWhisper/models"
FILE="ggml-${MODEL}.bin"
URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${FILE}"

if [[ "${MODEL}" == "-h" || "${MODEL}" == "--help" ]]; then
  cat <<'EOF'
usage: download-model.sh [model]

Multilingual models (approximate size):
  tiny             75 MB   fastest, lowest accuracy
  base            142 MB   quick tests
  small           466 MB   decent
  medium          1.5 GB   good
  large-v3        2.9 GB   best accuracy
  large-v3-turbo  1.5 GB   near-best accuracy, much faster (default)

Quantized variants also work, e.g. large-v3-turbo-q5_0, medium-q5_0.
English-only variants: tiny.en, base.en, small.en, medium.en.
EOF
  exit 0
fi

mkdir -p "$DIR"
if [[ -f "$DIR/$FILE" ]]; then
  echo "already downloaded: $DIR/$FILE"
  exit 0
fi
echo "downloading $FILE ..."
curl -L --fail -C - --progress-bar -o "$DIR/$FILE.part" "$URL"
mv "$DIR/$FILE.part" "$DIR/$FILE"
echo "saved: $DIR/$FILE"
