#!/usr/bin/env bash
# Regenerate every image/video in docs/media/ from the VHS tapes in media/.
#
#   ./media/capture.sh            # all media
#   ./media/capture.sh demo       # only media/demo.tape
#
# Safe to run on your own machine: the tapes run update.sh against stub
# `apt-get`/`id` commands inside a throwaway tmux server (see media/demo-env.sh).
# Nothing is installed, upgraded or run as root.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"

export UPDATE_STUFF_DEMO_DIR="${TMPDIR:-/tmp}/update_stuff-demo"

# --- prerequisites ---
missing=()
for tool in vhs ttyd ffmpeg tmux; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if ((${#missing[@]})); then
    printf 'missing prerequisites: %s\n' "${missing[*]}" >&2
    printf 'Arch Linux:\n  sudo pacman -S --needed vhs ttyd ffmpeg tmux ttf-jetbrains-mono\n' >&2
    printf '  (or: go install github.com/charmbracelet/vhs@latest)\nSee media/README.md for details.\n' >&2
    exit 1
fi
if ! fc-list 2>/dev/null | grep -qi "JetBrains Mono"; then
    printf 'note: "JetBrains Mono" font not found, VHS will fall back to another monospace font\n' >&2
fi

cleanup() {
    TMUX_TMPDIR="$UPDATE_STUFF_DEMO_DIR/tmux" tmux kill-server 2>/dev/null || true
    rm -rf -- "$UPDATE_STUFF_DEMO_DIR"
}
trap cleanup EXIT

mkdir -p docs/media

tapes=()
if (($#)); then
    for name in "$@"; do tapes+=("media/${name%.tape}.tape"); done
else
    tapes=(media/demo.tape media/dry-run.tape media/background.tape)
fi

for tape in "${tapes[@]}"; do
    [[ -f "$tape" ]] || { printf 'no such tape: %s\n' "$tape" >&2; exit 1; }
    printf '==> recording %s\n' "$tape"
    cleanup # fresh sandbox + tmux server for every tape
    vhs "$tape"
done

# Optional: rasterise the social preview (upload it under Settings -> Social preview).
if command -v rsvg-convert >/dev/null 2>&1; then
    printf '==> rendering docs/media/social.png\n'
    rsvg-convert -w 1280 -h 640 .github/brand/social.svg -o docs/media/social.png
else
    printf 'skip: rsvg-convert not found (pacman -S librsvg) — docs/media/social.png not rendered\n'
fi

printf '==> done:\n'
ls -lh docs/media/
