# fork sync

Weekly upstream merge for this fork, gated on tests passing, not on the absence of conflicts.

| branch        | holds                                   | written by                        |
|---------------|-----------------------------------------|-----------------------------------|
| `port`        | the fork's changes (default branch)     | you, and merged sync PRs          |
| `integration` | last run's upstream merge, pre-review   | `.github/workflows/fork-sync.yml` |
| `sync/failed` | last red merge, parked for inspection   | the workflow                      |
| `device`      | exactly what the comma installs         | `promote.sh`, by hand, only       |

Rulesets enforce it: `port` and `device` cannot be force-pushed or deleted, and only an admin (you)
can update them, so the workflow and the repair agent physically cannot write either.

## What a run does

1. `detect.sh`: fetch upstream (`config.sh: UPSTREAM_BRANCHES`). If `port` already contains it, or nothing
   moved since the last run, exit silently. Most runs end here.
2. `merge.sh`: reset `integration` to `port`, merge each upstream branch.
3. Clean merge: `gate.sh` runs the safety suite, lint + unit tests, and a car behavior report that replays
   Subaru segments on `port` and on `integration` and fails on any difference (`port_diff.py`).
   Green opens or refreshes a PR `integration -> port`. Red parks the merge on `sync/failed` and reports.
4. Conflict: anything matching `STOP_PATHS` (`opendbc/safety/`) or a delete/rename conflict stops the run.
   Otherwise the repair agent (claude-code-action) edits the conflicted files and writes `RESOLUTION.md`.
   `verify.sh` then rejects the attempt if it left markers, took either side wholesale, or touched any other
   file. A verified resolution goes through the same gate, once.

Notifications are comments on the `fork-sync` status issue, posted only when the outcome changes.
Scheduled runs always exit 0 so GitHub does not email you about every red week.

## Promoting to the car

Read the PR, merge it into `port`, then from a local clone:

    .github/fork-sync/promote.sh          # show what would go to device
    .github/fork-sync/promote.sh --yes    # merge port into device (never rebase), tag deployed/<date>-<n>

Each `deployed/*` tag records the previous device commit as the rollback target. Roll back with
`git revert -m 1 <promotion merge>` on `device`, never a force push. Don't promote right before a drive
that matters.

## Setup

- Secret `ANTHROPIC_API_KEY` (only needed when a merge conflicts).
- Actions → General: workflow permissions read/write, and "Allow GitHub Actions to create pull requests".
- Manual run: Actions → fork sync → Run workflow (tick `force` to rerun an unchanged upstream).
