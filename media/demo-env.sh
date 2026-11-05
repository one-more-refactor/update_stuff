#!/usr/bin/env bash
# Sourced by the VHS tapes (hidden) to build a harmless demo sandbox:
#   - stub `id` (pretends to be root) and stub `apt-get` (fake output)
#   - `update-stuff` on PATH, pointing at this repo's update.sh
#   - a private tmux server + config, so your own tmux is never touched
#   - `sudo` is a no-op function, so the demo shows the real command
# shellcheck disable=SC2034 # PS1 is used by the interactive shell

demo_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
demo_dir="${UPDATE_STUFF_DEMO_DIR:-${TMPDIR:-/tmp}/update_stuff-demo}"

mkdir -p "$demo_dir/bin" "$demo_dir/home" "$demo_dir/tmux"
cp "$demo_repo/media/stubs/id" "$demo_repo/media/stubs/apt-get" "$demo_dir/bin/"
ln -sf "$demo_repo/update.sh" "$demo_dir/bin/update-stuff"
chmod +x "$demo_dir/bin/"*

cat >"$demo_dir/home/.tmux.conf" <<'EOF'
set -g status-style "bg=#3DDC97,fg=#0F1420"
set -g status-left " update_stuff "
set -g status-left-length 20
set -g status-right " demo · nothing is really updated "
set -g status-right-length 40
set -g window-status-format ""
set -g window-status-current-format ""
EOF

export HOME="$demo_dir/home"
unset XDG_CONFIG_HOME TMUX
export TMUX_TMPDIR="$demo_dir/tmux"
export PATH="$demo_dir/bin:$PATH"
export UPDATE_STUFF_PM=apt
export HOSTNAME=lxc-104
PS1='\[\e[38;2;61;220;151m\]root@lxc-104\[\e[0m\]:\[\e[38;2;255;181;71m\]~\[\e[0m\]# '
sudo() { "$@"; }
