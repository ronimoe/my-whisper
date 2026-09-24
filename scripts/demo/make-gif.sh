#!/usr/bin/env bash
# Regenerate docs/images/demo.gif, the README's illustrated demo (not a screen
# recording). Needs Google Chrome, Node 22+, and ffmpeg. Edit demo.html to
# change the scene; it mirrors RecordingPill.swift and MenuBarIcon.swift.
set -euo pipefail
cd "$(dirname "$0")/../.."

FRAMES=$(mktemp -d)
trap 'rm -rf "$FRAMES"' EXIT

node scripts/demo/capture.mjs "$FRAMES" 12 9 2
# Full 256-color palette + ordered dither: error-diffusion dithering scatters
# the red recording-icon color into the pill's shadow.
ffmpeg -loglevel error -y -framerate 12 -i "$FRAMES/f%04d.png" \
  -vf "scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 docs/images/demo.gif
echo "wrote docs/images/demo.gif"
