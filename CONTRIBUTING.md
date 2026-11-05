# Contributing

Thanks for wanting to make `update_stuff` better! It's one Bash file, so the bar is
simple: keep it small, readable and safe to pipe into `sudo bash`.

## Ground rules

- **One file.** `update.sh` must keep working when fetched with
  `curl … | sudo bash`, so no sourcing of sibling files.
- **Bash ≥ 4**, `set -euo pipefail`, and **shellcheck-clean** (`shellcheck -x update.sh`).
- New behaviour gets a [bats](https://github.com/bats-core/bats-core) test in `test/`.
  Tests never touch the real system: every external command is a stub (see
  `test/test_helper.bash`).
- Conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `ci:`, `chore:`.

## Running the checks

```bash
bash -n update.sh
shellcheck -x update.sh media/capture.sh media/demo-env.sh media/stubs/* test/test_helper.bash
bats test/
```

CI (`.github/workflows/ci.yml`) runs exactly these on every push and pull request.

## Adding a package manager

1. Add it to the detection loop in `detect_package_manager`.
2. Add its non-interactive upgrade chain to `upgrade_commands`.
3. Add it to the tests in `test/answers.bats` and `test/update.bats`, and to the
   table in `docs/configuration.md`.

## Media

Screenshots/GIFs are generated, never hand-made: see [`media/README.md`](media/README.md).
