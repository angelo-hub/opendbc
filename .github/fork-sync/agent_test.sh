#!/usr/bin/env bash
# The only way the repair agent runs tests: pytest inside the repo's environment, nothing else.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
# shellcheck source=/dev/null
source ./setup.sh > /dev/null
exec python -m pytest -q "$@"
