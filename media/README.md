# media/

Everything in [`docs/media/`](../docs/media) is generated from this folder — no
hand-made screenshots. The tapes run the real `update.sh` against **stub**
`apt-get`/`id` commands in a throwaway tmux server, so recording is harmless:
nothing is upgraded and nothing runs as root.

| Source | Output |
| --- | --- |
| `demo.tape` | `docs/media/demo.gif`, `demo.mp4`, `demo.webm` (README hero) |
| `dry-run.tape` | `docs/media/dry-run.gif` |
| `background.tape` | `docs/media/background.gif` |
| `../.github/brand/social.svg` | `docs/media/social.png` (if `rsvg-convert` is installed) |

Helpers: `demo-env.sh` (builds the sandbox, sourced invisibly by each tape) and
`stubs/` (fake `apt-get` with realistic output, fake `id`).

## Prerequisites (Arch Linux)

```bash
sudo pacman -S --needed vhs ttyd ffmpeg tmux ttf-jetbrains-mono librsvg
# VHS from source instead of the package:
#   sudo pacman -S --needed go && go install github.com/charmbracelet/vhs@latest
```

## Run

```bash
./media/capture.sh          # everything
./media/capture.sh demo     # just one tape
```

The script checks its prerequisites, records each tape into `docs/media/`, then
kills its private tmux server and deletes its sandbox (`$TMPDIR/update_stuff-demo`).
Commit the results in `docs/media/`.

Tweak timing with `DEMO_SPEED` (multiplier for the fake apt output) inside a
tape, and keep `Set Width/Height/FontSize/Theme` as they are so the GIFs stay
consistent with each other.
