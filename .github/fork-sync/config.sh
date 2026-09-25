# fork-sync settings for angelo-hub/opendbc (Subaru angle-steering port, 2024 Outback).
# Sourced by lib.sh.

UPSTREAM_URL=https://github.com/commaai/opendbc.git
# crosstrek is the head of commaai/opendbc#3795; it is skipped automatically once deleted after merge.
UPSTREAM_BRANCHES="crosstrek master"
PORT_BRANCH=port
INTEGRATION_BRANCH=integration
FAILED_BRANCH=sync/failed

# Conflicts here stop the run. An agent picking a side in the steering safety model is exactly
# the failure this setup exists to prevent.
STOP_PATHS='^opendbc/safety/'

# Car behavior report: replay these platforms on port and on integration and diff the CarState streams.
CAR_DIFF_PLATFORMS="SUBARU_OUTBACK_2023 SUBARU_CROSSTREK_2025 SUBARU_ASCENT_2023 SUBARU_FORESTER_2022"
CAR_DIFF_SEGMENTS=10

PROMPT_NOTES="This fork carries the Subaru angle-based steering port (lineage of commaai/opendbc#2864 and #3795) for a
2024 Outback (platform SUBARU_OUTBACK_2023). Upstream frequently renames CAN signals, changes function signatures,
and moves code; when it does, carry the port's logic over to the new names and signatures rather than dropping it.
Conflicts under opendbc/safety/ never reach you; they stop the run."

extra_fingerprint() { :; }
extra_needed() { return 1; }
repo_fixups() { return 0; }
