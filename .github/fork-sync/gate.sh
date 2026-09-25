#!/usr/bin/env bash
# The gate: tests passing, not the absence of conflicts. Run on the integration checkout.
#
# Red means the merge made something worse than port. A check that fails is re-run on a port checkout;
# if it fails there too it is reported as pre-existing (⚠️) and does not turn the gate red, otherwise a
# known failure on the port branch would make every run red and the reports would stop being read.
# Checks are kept small (one lefthook command each) so a pre-existing failure cannot mask a new one.
#
# Writes $WORK/gate.md and sets GATE=green|red.
source "$(dirname "$0")/lib.sh"

report="$WORK/gate.md"
: > "$report"
status=green
PORT_TREE="$WORK/port-tree"

rm -rf "$PORT_TREE"
git worktree add -q --detach "$PORT_TREE" "origin/$PORT_BRANCH"

details() {
  { echo; echo '  <details><summary>last 80 lines</summary>'; echo
    echo '  ```'; tail -n 80 "$1" | sed 's/^/  /'; echo '  ```'; echo '  </details>'; } >> "$report"
}

# step <name> <command...>   (command runs in the repo's environment, from the repo root)
step() {
  local name=$1; shift
  local slug; slug=$(echo "$name" | tr -c 'a-zA-Z0-9\n' '_')
  local logf="$WORK/gate-$slug.log"
  log "gate: $name"
  echo "::group::$name"
  if (source ./setup.sh >/dev/null && "$@") > "$logf" 2>&1; then
    echo "- ✅ $name" >> "$report"
  elif grep -qE 'Incorrect Usage|command not found|No such file or directory|ModuleNotFoundError' "$logf"; then
    # A check that cannot even start fails the same way on port; never let that pass as pre-existing.
    status=red
    echo "- ❌ **$name** could not run" >> "$report"
    details "$logf"
  elif (cd "$PORT_TREE" && source ./setup.sh >/dev/null && "$@") > "$logf.port" 2>&1; then
    status=red
    echo "- ❌ **$name** (passes on \`$PORT_BRANCH\`, fails after the merge)" >> "$report"
    details "$logf"
  else
    echo "- ⚠️ $name: fails on \`$PORT_BRANCH\` too (pre-existing, not counted)" >> "$report"
    details "$logf"
  fi
  cat "$logf"; echo "::endgroup::"
}

step "safety suite (opendbc/safety/tests/test.sh)" ./opendbc/safety/tests/test.sh
for c in misra cpplint ruff ty codespell unittest; do
  step "lefthook: $c" lefthook run test --command "$c"
done
# shellcheck disable=SC2086
step "panda safety vs CarState on test routes ($CAR_DIFF_PLATFORMS)" \
  python "$SYNC_DIR/test_platform_models.py" $CAR_DIFF_PLATFORMS

# Car behavior report against port, not against comma master: the port is supposed to differ from
# master, but the merge is not supposed to change what the port does. Relative by construction, so no
# port re-run: any difference is red.
log "gate: car behavior report"
echo "::group::car behavior report"
# shellcheck disable=SC2086
if (source ./setup.sh >/dev/null && python "$SYNC_DIR/port_diff.py" --base "$PORT_TREE" \
      --segments "$CAR_DIFF_SEGMENTS" --report "$WORK/car_diff.md" $CAR_DIFF_PLATFORMS) > "$WORK/car_diff.log" 2>&1; then
  echo "- ✅ car behavior report: integration replays identically to \`$PORT_BRANCH\`" >> "$report"
else
  status=red
  echo "- ❌ **car behavior report**: see below" >> "$report"
  [ -s "$WORK/car_diff.md" ] || details "$WORK/car_diff.log"
fi
grep -v "CANParser: .* not valid" "$WORK/car_diff.log" || true
echo "::endgroup::"
[ -s "$WORK/car_diff.md" ] && { echo; cat "$WORK/car_diff.md"; } >> "$report"

git worktree remove --force "$PORT_TREE"
setvar GATE "$status"
