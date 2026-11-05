#!/usr/bin/env bash
#
# update_stuff — update a box inside a tmux session, then get out of the way.
#
# Detects the package manager (apt, dnf, pacman, zypper), runs the full
# upgrade inside a named tmux session so a dropped SSH connection can't kill it
# halfway, and optionally attaches, logs to a file and pings ntfy when done.
#
#   curl -fsSL https://raw.githubusercontent.com/one-more-refactor/update_stuff/main/update.sh | sudo bash
#   sudo ./update.sh --attach --log /var/log/update_stuff.log
#
# Every option is documented in README.md and docs/. MIT licensed.

set -euo pipefail

readonly VERSION="1.0.0"
readonly RAW_URL="https://raw.githubusercontent.com/one-more-refactor/update_stuff/main/update.sh"

# --- Defaults (each can be overridden by an UPDATE_STUFF_* env var or a flag) ---
session_name="${UPDATE_STUFF_SESSION:-update_stuff}"
prompt_timeout="${UPDATE_STUFF_PROMPT_TIMEOUT:-5}" # seconds to wait for "attach? (y/N)"; 0 = don't ask
hold_seconds="${UPDATE_STUFF_HOLD:-10}"           # keep the finished session open this long; 0 = close at once
log_file="${UPDATE_STUFF_LOG:-}"
ntfy_url="${UPDATE_STUFF_NTFY_URL:-}"
package_manager="${UPDATE_STUFF_PM:-}"
tty_path="${UPDATE_STUFF_TTY:-/dev/tty}"
install_path="${UPDATE_STUFF_INSTALL_PATH:-/usr/local/bin/update-stuff}"

attach_mode="ask" # ask | yes | no
dry_run=0
debug=0
do_install=0

# --- Output helpers ---
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    c_bold=$'\e[1m' c_dim=$'\e[2m' c_green=$'\e[32m' c_yellow=$'\e[33m' c_red=$'\e[31m' c_reset=$'\e[0m'
else
    c_bold="" c_dim="" c_green="" c_yellow="" c_red="" c_reset=""
fi

info() { printf '%s==>%s %s\n' "$c_green$c_bold" "$c_reset" "$*"; }
warn() { printf '%swarning:%s %s\n' "$c_yellow$c_bold" "$c_reset" "$*" >&2; }
die() {
    printf '%serror:%s %s\n' "$c_red$c_bold" "$c_reset" "$*" >&2
    exit 1
}
debug_log() { if ((debug)); then printf '%s[debug] %s%s\n' "$c_dim" "$*" "$c_reset" >&2; fi; }
usage_error() {
    printf 'error: %s\nTry: update.sh --help\n' "$*" >&2
    exit 2
}

usage() {
    cat <<EOF
update_stuff ${VERSION} — update this box inside a tmux session.

Usage: update.sh [options]
       curl -fsSL ${RAW_URL} | sudo bash -s -- [options]

Options:
  -a, --attach            attach to the update session without asking
  -D, --detach            run in the background without asking
  -n, --dry-run           show what would run, change nothing (no root needed)
  -l, --log FILE          append all update output to FILE
      --ntfy URL          POST a notification to this ntfy topic URL when done
  -s, --session NAME      tmux session name (default: update_stuff)
      --pm NAME           force a package manager: apt, dnf, pacman, zypper
  -t, --timeout SECONDS   how long to wait at the attach prompt (0 = don't ask)
      --hold SECONDS      keep the finished session open this long (0 = close)
      --install           install this script as ${install_path}
  -d, --debug             print debug information
  -h, --help              show this help
  -V, --version           print the version

Environment: UPDATE_STUFF_SESSION, UPDATE_STUFF_LOG, UPDATE_STUFF_NTFY_URL,
UPDATE_STUFF_PM, UPDATE_STUFF_PROMPT_TIMEOUT, UPDATE_STUFF_HOLD,
UPDATE_STUFF_INSTALL_PATH, NO_COLOR.
EOF
}

# --- Argument handling ---
need_value() { [[ $# -ge 2 && -n "$2" ]] || usage_error "$1 needs a value"; }
is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a | --attach) attach_mode="yes" ;;
            -D | --detach) attach_mode="no" ;;
            -n | --dry-run) dry_run=1 ;;
            -d | --debug) debug=1 ;;
            -l | --log) need_value "$@"; log_file="$2"; shift ;;
            --log=*) log_file="${1#*=}" ;;
            --ntfy) need_value "$@"; ntfy_url="$2"; shift ;;
            --ntfy=*) ntfy_url="${1#*=}" ;;
            -s | --session) need_value "$@"; session_name="$2"; shift ;;
            --session=*) session_name="${1#*=}" ;;
            --pm) need_value "$@"; package_manager="$2"; shift ;;
            --pm=*) package_manager="${1#*=}" ;;
            -t | --timeout) need_value "$@"; prompt_timeout="$2"; shift ;;
            --timeout=*) prompt_timeout="${1#*=}" ;;
            --hold) need_value "$@"; hold_seconds="$2"; shift ;;
            --hold=*) hold_seconds="${1#*=}" ;;
            --install) do_install=1 ;;
            -h | --help) usage; exit 0 ;;
            -V | --version) printf 'update_stuff %s\n' "$VERSION"; exit 0 ;;
            *) usage_error "unknown option: $1" ;;
        esac
        shift
    done

    is_uint "$prompt_timeout" || usage_error "--timeout must be a whole number of seconds"
    is_uint "$hold_seconds" || usage_error "--hold must be a whole number of seconds"
    [[ "$session_name" =~ ^[A-Za-z0-9_-]+$ ]] || usage_error "session name may only contain letters, digits, _ and -"
    return 0
}

# --- Prompting ---

# answer_is_yes ANSWER -> 0 yes, 1 no, 2 unrecognised.
# Accepts y/yes/yeah/yep/j/ja and n/no/nah/nope/nein; empty means no.
answer_is_yes() {
    local answer="${1,,}"
    answer="${answer//[[:space:]]/}"
    case "$answer" in
        y | yes | yeah | yep | j | ja) return 0 ;;
        n | no | nah | nope | nein | "") return 1 ;;
        *) return 2 ;;
    esac
}

# ask QUESTION -> 0 (yes) / 1 (no). Reads from the controlling terminal, so it
# also works when the script itself arrives on stdin via `curl | bash`.
# A timeout, an empty answer or no terminal at all count as "no".
ask() {
    local question="$1" answer rc tries=0
    if [[ "$prompt_timeout" -eq 0 ]]; then
        debug_log "prompt disabled (timeout 0), answering no"
        return 1
    fi
    if ! { exec 3<"$tty_path"; } 2>/dev/null; then
        debug_log "no terminal at $tty_path, answering no"
        return 1
    fi
    while ((tries < 3)); do
        tries=$((tries + 1))
        printf '%s (y/N, %ss) ' "$question" "$prompt_timeout" >&2
        answer=""
        if ! read -r -t "$prompt_timeout" answer <&3; then
            printf '\n' >&2
            exec 3<&-
            return 1
        fi
        rc=0
        answer_is_yes "$answer" || rc=$?
        if [[ $rc -ne 2 ]]; then
            exec 3<&-
            return "$rc"
        fi
        printf 'Please answer y or n.\n' >&2
    done
    exec 3<&-
    return 1
}

# --- Package managers ---
detect_package_manager() {
    if [[ -n "$package_manager" ]]; then
        printf '%s\n' "$package_manager"
        return 0
    fi
    local pm
    for pm in apt-get dnf pacman zypper; do
        if command -v "$pm" >/dev/null 2>&1; then
            [[ "$pm" == "apt-get" ]] && pm="apt"
            printf '%s\n' "$pm"
            return 0
        fi
    done
    return 1
}

# upgrade_commands PM -> the non-interactive upgrade command chain for PM.
upgrade_commands() {
    case "$1" in
        apt) printf '%s\n' 'export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get -y full-upgrade && apt-get -y autoremove && apt-get -y autoclean' ;;
        dnf) printf '%s\n' 'dnf -y upgrade --refresh && dnf -y autoremove' ;;
        pacman) printf '%s\n' 'pacman -Syu --noconfirm' ;;
        zypper) printf '%s\n' 'zypper --non-interactive refresh && zypper --non-interactive update' ;;
        *) return 1 ;;
    esac
}

# --- tmux ---
session_exists() { tmux has-session -t "=$session_name" 2>/dev/null; }

attach_session() {
    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "=$session_name"
    elif [[ -t 0 ]]; then
        tmux attach-session -t "=$session_name"
    else
        # stdin is the script itself (curl | bash): hand tmux the real terminal.
        tmux attach-session -t "=$session_name" <"$tty_path"
    fi
}

# render_runner COMMANDS -> the script that runs inside the tmux session.
render_runner() {
    local commands="$1"
    printf '#!/usr/bin/env bash\n'
    printf '# generated by update_stuff %s — deletes itself when it starts\n' "$VERSION"
    # shellcheck disable=SC2016 # $0 is meant for the generated script
    printf 'rm -f -- "$0"\n'
    printf 'log_file=%q\n' "$log_file"
    printf 'ntfy_url=%q\n' "$ntfy_url"
    printf 'hold_seconds=%q\n' "$hold_seconds"
    printf 'run_updates() {\n    %s\n}\n' "$commands"
    cat <<'RUNNER'
printf '==> update_stuff started on %s at %s\n' "${HOSTNAME:-?}" "$(date '+%F %T')"
if [[ -n "$log_file" ]]; then
    run_updates 2>&1 | tee -a -- "$log_file"
    status=${PIPESTATUS[0]}
else
    run_updates
    status=$?
fi
if [[ $status -eq 0 ]]; then
    message="Updates finished on ${HOSTNAME:-?}"
    tags="white_check_mark"
else
    message="Updates FAILED on ${HOSTNAME:-?} (exit $status)"
    tags="x"
fi
printf '==> %s\n' "$message"
if [[ -n "$log_file" ]]; then
    printf '==> %s at %s\n' "$message" "$(date '+%F %T')" >>"$log_file"
fi
if [[ -n "$ntfy_url" ]]; then
    curl -fsS -m 15 -H "Title: update_stuff" -H "Tags: $tags" -d "$message" "$ntfy_url" >/dev/null ||
        printf 'warning: could not reach ntfy at %s\n' "$ntfy_url" >&2
fi
if [[ $hold_seconds -gt 0 ]]; then
    read -r -s -n 1 -t "$hold_seconds" -p "Press any key to close (closes itself in ${hold_seconds}s)..." || true
    printf '\n'
fi
exit "$status"
RUNNER
}

# --- Install ---
install_self() {
    local source="${BASH_SOURCE[0]:-}"
    if ((dry_run)); then
        info "dry run: would install update_stuff to $install_path"
        return 0
    fi
    mkdir -p -- "$(dirname -- "$install_path")"
    if [[ -n "$source" && -f "$source" ]]; then
        install -m 0755 -- "$source" "$install_path"
    else
        # Running from a pipe (curl | bash): there is no file to copy, fetch it.
        command -v curl >/dev/null 2>&1 || die "curl is needed to install from a pipe"
        local tmp
        tmp="$(mktemp)"
        curl -fsSL "$RAW_URL" -o "$tmp" || {
            rm -f -- "$tmp"
            die "could not download $RAW_URL"
        }
        install -m 0755 -- "$tmp" "$install_path"
        rm -f -- "$tmp"
    fi
    info "installed $install_path — next time just run: sudo $(basename -- "$install_path")"
}

# --- Main ---
main() {
    parse_args "$@"
    debug_log "version=$VERSION session=$session_name attach=$attach_mode dry_run=$dry_run timeout=$prompt_timeout hold=$hold_seconds log=${log_file:-none} ntfy=${ntfy_url:-none}"

    if ((!dry_run)) && [[ "$(id -u)" -ne 0 ]]; then
        die "please run as root (sudo), or try --dry-run"
    fi

    if ((do_install)); then
        install_self
        return 0
    fi

    local pm commands
    pm="$(detect_package_manager)" || die "no supported package manager found (apt, dnf, pacman, zypper)"
    commands="$(upgrade_commands "$pm")" || die "unsupported package manager: $pm (use apt, dnf, pacman or zypper)"
    debug_log "package manager: $pm"

    if ((dry_run)); then
        info "dry run — nothing will be changed"
        printf '  package manager : %s\n' "$pm"
        printf '  tmux session    : %s\n' "$session_name"
        printf '  attach          : %s\n' "$attach_mode"
        printf '  log file        : %s\n' "${log_file:-none}"
        printf '  ntfy            : %s\n' "${ntfy_url:-none}"
        printf '  commands        : %s\n' "$commands"
        return 0
    fi

    command -v tmux >/dev/null 2>&1 || die "tmux is required — install it first (e.g. apt-get install tmux)"

    if session_exists; then
        warn "tmux session '$session_name' is already running — an update is probably in progress"
        case "$attach_mode" in
            yes) attach_session ;;
            no) info "leaving it alone. Attach later with: tmux attach -t $session_name" ;;
            ask)
                if ask "Attach to it?"; then
                    attach_session
                else
                    info "attach later with: tmux attach -t $session_name"
                fi
                ;;
        esac
        return 0
    fi

    if [[ -n "$log_file" ]]; then
        mkdir -p -- "$(dirname -- "$log_file")"
        touch -- "$log_file" || die "cannot write log file $log_file"
    fi

    local runner
    runner="$(mktemp "${TMPDIR:-/tmp}/update_stuff.XXXXXX")"
    render_runner "$commands" >"$runner"
    chmod 0700 "$runner"
    debug_log "runner script: $runner"

    if ! tmux new-session -d -s "$session_name" "bash $(printf '%q' "$runner")"; then
        rm -f -- "$runner"
        die "could not start tmux session '$session_name'"
    fi
    info "updating with $pm in tmux session '$session_name'"

    local attach=1
    case "$attach_mode" in
        yes) attach=0 ;;
        no) attach=1 ;;
        ask) if ask "Attach to the update session?"; then attach=0; fi ;;
    esac

    if [[ $attach -eq 0 ]]; then
        if session_exists; then
            attach_session
        else
            info "the update session already finished${log_file:+ — see $log_file}"
        fi
    else
        info "running in the background. Watch it with: tmux attach -t $session_name"
    fi
}

# Run main unless sourced (tests source this file to reach the functions).
# When piped into bash, BASH_SOURCE is empty, so main runs.
if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
