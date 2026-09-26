# fork-sync settings for angelo-hub/opendbc (Subaru angle-steering port, 2024 Outback).
# Sourced by lib.sh.
#
# Two lines live in this repo, because GitHub allows one fork per fork network and sunnypilot/opendbc
# is in commaai/opendbc's network. FORK_SYNC_LINE selects one:
#   comma  commaai/opendbc + the angle port (#3795, merged from crosstrek)
#   sp     sunnypilot/opendbc + the same port, delta-applied (see lib.sh: upstream specs)

case "${FORK_SYNC_LINE:-comma}" in
  comma)
    UPSTREAM_REMOTES="upstream=https://github.com/commaai/opendbc.git"
    # crosstrek is the head of commaai/opendbc#3795; it is skipped automatically once deleted after merge.
    UPSTREAM_SPECS="upstream/crosstrek upstream/master"
    PORT_BRANCH=port
    INTEGRATION_BRANCH=integration
    FAILED_BRANCH=sync/failed
    DEVICE_BRANCH=device
    DEPLOY_TAG_PREFIX=deployed
    STATE_LABEL=fork-sync
    STATE_TITLE="Upstream sync status"
    LINE_NOTES=""
    ;;
  sp)
    UPSTREAM_REMOTES="sunnypilot=https://github.com/sunnypilot/opendbc.git comma=https://github.com/commaai/opendbc.git"
    # crosstrek sits on comma master commits sunnypilot has not synced yet. Merging it would drag those in
    # (and recording it as a parent without them would make later sunnypilot syncs revert them), so only
    # the port's own changes are applied.
    UPSTREAM_SPECS="sunnypilot/master delta:comma/crosstrek@comma/master"
    PORT_BRANCH=sp-port
    INTEGRATION_BRANCH=sp-integration
    FAILED_BRANCH=sp-failed
    DEVICE_BRANCH=sp-device
    DEPLOY_TAG_PREFIX=deployed/sp
    STATE_LABEL=fork-sync-sp
    STATE_TITLE="Upstream sync status (sunnypilot)"
    LINE_NOTES="This is the sunnypilot line: sunnypilot's opendbc (MADS, stop-and-go, CP_SP/CC_SP interfaces) plus the
angle port. On LKAS_ANGLE platforms MADS and stop-and-go are deliberately gated off; keep them gated off."
    ;;
  *)
    echo "unknown FORK_SYNC_LINE '${FORK_SYNC_LINE}'" >&2
    exit 1
    ;;
esac
DELTA_TRAILER=Angle-Port

# Conflicts here stop the run. An agent picking a side in the steering safety model is exactly
# the failure this setup exists to prevent.
STOP_PATHS='^opendbc/safety/'

# Car behavior report: replay these platforms on port and on integration and diff the CarState streams.
CAR_DIFF_PLATFORMS="SUBARU_OUTBACK_2023 SUBARU_CROSSTREK_2025 SUBARU_ASCENT_2023 SUBARU_FORESTER_2022"
CAR_DIFF_SEGMENTS=10

PROMPT_NOTES="This fork carries the Subaru angle-based steering port (lineage of commaai/opendbc#2864 and #3795) for a
2024 Outback (platform SUBARU_OUTBACK_2023). Upstream frequently renames CAN signals, changes function signatures,
and moves code; when it does, carry the port's logic over to the new names and signatures rather than dropping it.
Conflicts under opendbc/safety/ never reach you; they stop the run.
$LINE_NOTES"

extra_fingerprint() { :; }
extra_needed() { return 1; }
repo_fixups() { return 0; }
