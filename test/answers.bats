#!/usr/bin/env bats
# Unit tests for the answer parser (update.sh is sourced, main is not run).

load test_helper

setup() {
    # shellcheck source=../update.sh
    source "$BATS_TEST_DIRNAME/../update.sh"
    # update.sh enables strict mode; give bats its normal shell back.
    set +euo pipefail
}

@test "yes-ish answers are yes" {
    for a in y Y yes YES yeah yep j ja " y "; do
        run answer_is_yes "$a"
        [ "$status" -eq 0 ] || { echo "failed on '$a'"; false; }
    done
}

@test "no-ish and empty answers are no" {
    for a in n no NO nah nope nein ""; do
        run answer_is_yes "$a"
        [ "$status" -eq 1 ] || { echo "failed on '$a'"; false; }
    done
}

@test "anything else is unrecognised" {
    for a in maybe 1 ok; do
        run answer_is_yes "$a"
        [ "$status" -eq 2 ] || { echo "failed on '$a'"; false; }
    done
}

@test "every supported package manager has an upgrade command" {
    for pm in apt dnf pacman zypper; do
        run upgrade_commands "$pm"
        [ "$status" -eq 0 ]
        [ -n "$output" ]
    done
    run upgrade_commands brew
    [ "$status" -eq 1 ]
}

@test "the generated runner is valid bash and quotes its settings" {
    log_file="/tmp/it's here.log" ntfy_url='https://ntfy.sh/a b' hold_seconds=3
    render_runner 'echo hi' >"$BATS_TEST_TMPDIR/runner"
    bash -n "$BATS_TEST_TMPDIR/runner"
    grep -qF "log_file=/tmp/it\\'s\\ here.log" "$BATS_TEST_TMPDIR/runner"
}
