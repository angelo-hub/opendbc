# fork sync

Weekly upstream sync for this fork, gated on tests passing, not on the absence of conflicts.

Two lines live here, because GitHub allows one fork per network and sunnypilot/opendbc is in
commaai/opendbc's network. `FORK_SYNC_LINE` in `config.sh` selects one:

| line    | port / integration / failed / device          | upstreams                                              |
|---------|-----------------------------------------------|--------------------------------------------------------|
| `comma` | `port`, `integration`, `sync/failed`, `device` | commaai `crosstrek` (#3795) + `master`, merged          |
| `sp`    | `sp-port`, `sp-integration`, `sp-failed`, `sp-device` | sunnypilot `master` merged + commaai `crosstrek` **delta-applied** |

`port` (the default branch) also holds these tools; the workflow runs them from there against each line.

**Delta apply.** crosstrek sits on comma master commits sunnypilot has not synced. Merging it would drag
those in, and recording it as a parent without them would make later sunnypilot syncs silently revert them.
So the sp line applies only crosstrek's own changes (3-way, base = `merge-base(crosstrek, comma/master)`) as
a single-parent commit with an `Angle-Port: <sha>` trailer. Re-applying after crosstrek moves only adds the
new port changes. When #3795 merges and crosstrek is deleted, the spec is skipped; sunnypilot then brings the
port in through its own comma sync, and the first sp merge after that conflicts once in `safety/subaru.h`
(a stop path): move to sunnypilot's version by hand.

**sp line, angle platforms:** sunnypilot's MADS and stop-and-go are gated off on `LKAS_ANGLE` cars until
validated on a real route.

Rulesets enforce it: the port and device branches of both lines cannot be force-pushed or deleted, and only an admin (you)
can update them, so the workflow and the repair agent physically cannot write either.

## What a run does

1. `detect.sh`: fetch upstream (`config.sh: UPSTREAM_SPECS`). If the port branch already contains it, or
   nothing moved since the last run, exit silently. Most runs end here.
2. `merge.sh`: reset integration to port, merge or delta-apply each upstream spec.
3. Clean merge: `gate.sh` runs the safety suite, each lefthook check (misra, cpplint, ruff, ty, codespell,
   unittest), upstream's panda-safety-vs-CarState route test for the Subaru angle platforms
   (`test_platform_models.py`), and a car behavior report that replays Subaru segments on `port` and on
   `integration` and fails on any difference (`port_diff.py`). Platforms with no public segments
   (OUTBACK_2023, CROSSTREK_2025, ASCENT_2023) fall back to their routes.py test route.
   A check that also fails on `port` is reported ⚠️ pre-existing and does not turn the gate red.
   Green opens or refreshes a PR `integration -> port`. Red parks the merge on `sync/failed` and reports.
4. Conflict: anything matching `STOP_PATHS` (`opendbc/safety/`) or a delete/rename conflict stops the run.
   Otherwise the repair agent (claude-code-action) edits the conflicted files and writes `RESOLUTION.md`.
   `verify.sh` then rejects the attempt if it left markers, took either side wholesale, or touched any other
   file. A verified resolution goes through the same gate, once.

Notifications are comments on the `fork-sync` status issue, posted only when the outcome changes.
Scheduled runs always exit 0 so GitHub does not email you about every red week.

## Promoting to the car

Read the PR, merge it into `port`, then from a local clone:

    .github/fork-sync/promote.sh [--line sp]          # show what would go to device
    .github/fork-sync/promote.sh [--line sp] --yes    # merge port into device (never rebase), tag deployed[/sp]/<date>-<n>

Each `deployed/*` tag records the previous device commit as the rollback target. Roll back with
`git revert -m 1 <promotion merge>` on `device`, never a force push. Don't promote right before a drive
that matters.

## Setup

- Secret `ANTHROPIC_API_KEY` (only needed when a merge conflicts).
- Actions → General: workflow permissions read/write, and "Allow GitHub Actions to create pull requests".
- Manual run: Actions → fork sync → Run workflow (pick a line; tick `force` to rerun an unchanged upstream).
