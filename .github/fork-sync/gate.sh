#!/usr/bin/env bash
# The gate: tests passing, not the absence of conflicts. Run on the integration checkout.
# Writes $WORK/gate.md and sets GATE=green|red.
source "$(dirname "$0")/lib.sh"

report="$WORK/gate.md"
: > "$report"
status=green

step() {
  local name=$1; shift
  local logf="$WORK/gate-$(echo "$name" | tr ' /' '__').log"
  log "gate: $name"
  if "$@" > "$logf" 2>&1; then
    echo "- ✅ $name" >> "$report"
  else
    status=red
    { echo "- ❌ **$name**"; echo; echo '  <details><summary>last 80 lines</summary>'; echo
      echo '  ```'; tail -n 80 "$logf" | sed 's/^/  /'; echo '  ```'; echo '  </details>'; } >> "$report"
  fi
  echo "::group::$name"; cat "$logf"; echo "::endgroup::"
}

# shellcheck source=/dev/null
source ./setup.sh > "$WORK/setup.log" 2>&1 || { cat "$WORK/setup.log"; echo "- ❌ **setup.sh**" >> "$report"; setvar GATE red; exit 0; }

step "safety suite (opendbc/safety/tests/test.sh)" ./opendbc/safety/tests/test.sh
step "lint + unit tests (lefthook run test)" lefthook run test

# Car behavior report against port, not against comma master: the port is supposed to differ from
# master, but tonight's merge is not supposed to change what the port does.
rm -rf "$WORK/port-tree"
git worktree add -q --detach "$WORK/port-tree" "origin/$PORT_BRANCH"
# shellcheck disable=SC2086
step "car behavior report vs port ($CAR_DIFF_PLATFORMS)" \
  python "$SYNC_DIR/port_diff.py" --base "$WORK/port-tree" --segments "$CAR_DIFF_SEGMENTS" \
    --report "$WORK/car_diff.md" $CAR_DIFF_PLATFORMS
git worktree remove --force "$WORK/port-tree"
if [ -s "$WORK/car_diff.md" ]; then
  { echo; cat "$WORK/car_diff.md"; } >> "$report"
fi

setvar GATE "$status"
