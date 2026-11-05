# Shared setup for the bats suite: every external command update.sh touches
# (id, tmux, apt-get, dnf, pacman, curl) is replaced by a stub in $STUB_BIN
# that records its arguments in $STUB_LOG. Nothing real is ever updated.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
SCRIPT="$REPO_ROOT/update.sh"

setup() {
    STUB_BIN="$BATS_TEST_TMPDIR/bin"
    STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
    export STUB_LOG STUB_DIR="$BATS_TEST_TMPDIR"
    mkdir -p "$STUB_BIN"
    : >"$STUB_LOG"

    # Pretend to be root unless a test says otherwise.
    stub id 'echo "${STUB_UID:-0}"'
    # tmux: has-session answers from $STUB_SESSION_EXISTS; new-session runs the
    # command synchronously (like a session that finishes instantly).
    stub tmux '
case "$1" in
    has-session) [[ "${STUB_SESSION_EXISTS:-0}" == 1 ]] ;;
    new-session) cmd="${*: -1}"; eval "$cmd" >"$STUB_DIR/session.out" 2>&1 || true ;;
    *) exit 0 ;;
esac'
    stub curl 'exit 0'

    # update.sh only ever sees the stubs plus a handful of core utilities, so a
    # real apt-get/tmux on the test machine (e.g. a CI runner) is never visible.
    CORE_BIN="$BATS_TEST_TMPDIR/core"
    mkdir -p "$CORE_BIN"
    local tool path
    for tool in bash env cat chmod mktemp rm mkdir touch dirname basename date tee grep install cmp ls; do
        path="$(command -v "$tool")" && ln -sf "$path" "$CORE_BIN/$tool"
    done
    SANDBOX_PATH="$STUB_BIN:$CORE_BIN"

    export NO_COLOR=1 TMPDIR="$BATS_TEST_TMPDIR"
    export UPDATE_STUFF_HOLD=0 UPDATE_STUFF_PROMPT_TIMEOUT=0
    export UPDATE_STUFF_TTY="$BATS_TEST_TMPDIR/no-tty"
    unset TMUX UPDATE_STUFF_SESSION UPDATE_STUFF_LOG UPDATE_STUFF_NTFY_URL UPDATE_STUFF_PM
}

# run_update ARGS... — run update.sh inside the sandboxed PATH (bats `run`).
run_update() {
    run env PATH="$SANDBOX_PATH" "$CORE_BIN/bash" "$SCRIPT" "$@"
}

# stub NAME BODY — create an executable stub that logs "NAME args" then runs BODY.
stub() {
    local name="$1" body="${2:-exit 0}"
    cat >"$STUB_BIN/$name" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$name" "\$*" >>"\$STUB_LOG"
$body
EOF
    chmod +x "$STUB_BIN/$name"
}

# Fail with the call log printed if PATTERN never appears in it.
assert_called() {
    grep -qE -- "$1" "$STUB_LOG" || {
        printf 'expected a call matching: %s\ncalls were:\n' "$1" >&2
        cat "$STUB_LOG" >&2
        return 1
    }
}

refute_called() {
    if grep -qE -- "$1" "$STUB_LOG"; then
        printf 'unexpected call matching: %s\ncalls were:\n' "$1" >&2
        cat "$STUB_LOG" >&2
        return 1
    fi
}
