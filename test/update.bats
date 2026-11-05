#!/usr/bin/env bats
# Integration tests: run update.sh end to end against stubbed tmux/apt/etc.

load test_helper

@test "--help prints usage and exits 0" {
    run_update --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: update.sh"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "--version prints the version" {
    run_update --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^update_stuff\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "unknown options exit 2 with a hint" {
    run_update --frobnicate
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown option: --frobnicate"* ]]
}

@test "options that need a value complain when it's missing" {
    run_update --log
    [ "$status" -eq 2 ]
    [[ "$output" == *"--log needs a value"* ]]
}

@test "non-numeric timeouts are rejected" {
    run_update --timeout soon
    [ "$status" -eq 2 ]
    run_update --hold=-1
    [ "$status" -eq 2 ]
}

@test "unsafe session names are rejected" {
    run_update --session 'a b;rm'
    [ "$status" -eq 2 ]
}

@test "refuses to run without root" {
    stub apt-get
    STUB_UID=1000 run_update --detach
    [ "$status" -eq 1 ]
    [[ "$output" == *"run as root"* ]]
    refute_called '^tmux new-session'
}

@test "--dry-run works without root and changes nothing" {
    stub apt-get
    STUB_UID=1000 run_update --dry-run --log /var/log/x.log
    [ "$status" -eq 0 ]
    [[ "$output" == *"package manager : apt"* ]]
    [[ "$output" == *"apt-get -y full-upgrade"* ]]
    [[ "$output" == *"log file        : /var/log/x.log"* ]]
    refute_called '^tmux'
    refute_called '^apt-get'
}

@test "detects dnf, pacman and zypper" {
    for pm in dnf pacman zypper; do
        rm -f "$STUB_BIN"/{apt-get,dnf,pacman,zypper}
        stub "$pm"
        run_update --dry-run
        [ "$status" -eq 0 ]
        [[ "$output" == *"package manager : $pm"* ]]
    done
}

@test "--pm overrides detection, unknown --pm fails" {
    stub apt-get
    run_update --dry-run --pm pacman
    [[ "$output" == *"pacman -Syu --noconfirm"* ]]
    run_update --dry-run --pm brew
    [ "$status" -eq 1 ]
    [[ "$output" == *"unsupported package manager: brew"* ]]
}

@test "fails clearly when no package manager is found" {
    run_update --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"no supported package manager"* ]]
}

@test "fails clearly when tmux is missing" {
    stub apt-get
    rm "$STUB_BIN/tmux"
    run_update --detach
    [ "$status" -eq 1 ]
    [[ "$output" == *"tmux is required"* ]]
}

@test "runs the full apt upgrade inside a detached tmux session" {
    stub apt-get
    run_update --detach
    [ "$status" -eq 0 ]
    assert_called '^tmux new-session -d -s update_stuff '
    assert_called '^apt-get update'
    assert_called '^apt-get -y full-upgrade'
    assert_called '^apt-get -y autoremove'
    assert_called '^apt-get -y autoclean'
    refute_called '^tmux attach-session'
    [[ "$output" == *"tmux attach -t update_stuff"* ]]
}

@test "the runner script cleans up after itself" {
    stub apt-get
    run_update --detach
    [ "$status" -eq 0 ]
    run bash -c "ls '$BATS_TEST_TMPDIR'/update_stuff.* 2>/dev/null"
    [ -z "$output" ]
}

@test "stops at the first failing step" {
    stub apt-get '[[ "$1" != update ]] || exit 100'
    run_update --detach
    [ "$status" -eq 0 ]
    assert_called '^apt-get update'
    refute_called '^apt-get -y full-upgrade'
    grep -q 'Updates FAILED' "$STUB_DIR/session.out"
}

@test "--log tees the output into the log file" {
    stub apt-get 'echo "apt says $*"'
    run_update --detach --log "$BATS_TEST_TMPDIR/logs/update.log"
    [ "$status" -eq 0 ]
    grep -q 'apt says -y full-upgrade' "$BATS_TEST_TMPDIR/logs/update.log"
    grep -q 'Updates finished' "$BATS_TEST_TMPDIR/logs/update.log"
}

@test "--ntfy posts a success notification" {
    stub apt-get
    run_update --detach --ntfy https://ntfy.example/topic
    [ "$status" -eq 0 ]
    assert_called '^curl .*Tags: white_check_mark.*Updates finished on .* https://ntfy.example/topic$'
}

@test "--ntfy reports failures too" {
    stub apt-get 'exit 1'
    run_update --detach --ntfy=https://ntfy.example/topic
    assert_called '^curl .*Tags: x.*Updates FAILED'
}

@test "custom session names are used" {
    stub apt-get
    UPDATE_STUFF_SESSION=nightly run_update --detach
    assert_called '^tmux new-session -d -s nightly '
}

@test "--attach attaches when the session is still running" {
    stub apt-get
    STUB_SESSION_EXISTS=0 run_update --attach
    [[ "$output" == *"already finished"* ]]
    # second has-session (after start) says it's alive -> attach
    stub tmux '
case "$1" in
    has-session) [[ -e "$STUB_DIR/started" ]] ;;
    new-session) touch "$STUB_DIR/started" ;;
esac'
    run_update --attach
    [ "$status" -eq 0 ]
    assert_called '^tmux attach-session -t =update_stuff'
}

@test "an existing session is never started twice" {
    stub apt-get
    STUB_SESSION_EXISTS=1 run_update --detach
    [ "$status" -eq 0 ]
    [[ "$output" == *"already running"* ]]
    refute_called '^tmux new-session'
    refute_called '^apt-get'
}

@test "answering yes at the prompt attaches to an existing session" {
    stub apt-get
    printf 'maybe\nYes\n' >"$BATS_TEST_TMPDIR/tty"
    STUB_SESSION_EXISTS=1 UPDATE_STUFF_TTY="$BATS_TEST_TMPDIR/tty" UPDATE_STUFF_PROMPT_TIMEOUT=2 \
        run_update
    [ "$status" -eq 0 ]
    [[ "$output" == *"Please answer y or n."* ]]
    assert_called '^tmux attach-session -t =update_stuff'
}

@test "an empty answer means no" {
    stub apt-get
    printf '\n' >"$BATS_TEST_TMPDIR/tty"
    STUB_SESSION_EXISTS=1 UPDATE_STUFF_TTY="$BATS_TEST_TMPDIR/tty" UPDATE_STUFF_PROMPT_TIMEOUT=2 \
        run_update
    [ "$status" -eq 0 ]
    refute_called '^tmux attach-session'
}

@test "inside tmux it switches client instead of nesting" {
    stub apt-get
    STUB_SESSION_EXISTS=1 TMUX=/tmp/fake,1,0 run_update --attach
    assert_called '^tmux switch-client -t =update_stuff'
    refute_called '^tmux attach-session'
}

@test "works when piped into bash (curl | bash)" {
    stub apt-get
    run env PATH="$SANDBOX_PATH" "$CORE_BIN/bash" -c "bash -s -- --detach < '$SCRIPT'"
    [ "$status" -eq 0 ]
    assert_called '^apt-get -y full-upgrade'
}

@test "--install copies the script to the install path" {
    UPDATE_STUFF_INSTALL_PATH="$BATS_TEST_TMPDIR/bin2/update-stuff" run_update --install
    [ "$status" -eq 0 ]
    [ -x "$BATS_TEST_TMPDIR/bin2/update-stuff" ]
    cmp "$SCRIPT" "$BATS_TEST_TMPDIR/bin2/update-stuff"
}
