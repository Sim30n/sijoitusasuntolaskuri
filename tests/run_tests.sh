#!/usr/bin/env bash
# Runs the Robot Framework test suite for sijoitusasuntolaskuri.
#
# Usage:
#   tests/run_tests.sh                 # everything except the opt-in live-API check
#   tests/run_tests.sh unit            # only tests/unit
#   tests/run_tests.sh integration     # only tests/integration (still excludes live-api)
#   tests/run_tests.sh system          # only tests/system (launches the app + a headless browser)
#   tests/run_tests.sh live-api        # ONLY the opt-in live Anthropic API check
#                                       # requires ANTHROPIC_API_KEY and network egress
#
# One-time setup: pip install -r requirements.txt -r tests/requirements-test.txt && rfbrowser init
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SCOPE="${1:-all}"
OUTPUT_DIR="tests/results"
PYTHONPATH_ARG="tests/libraries"

mkdir -p "${OUTPUT_DIR}"

run_robot() {
    robot --pythonpath "${PYTHONPATH_ARG}" --outputdir "${OUTPUT_DIR}" "$@"
}

case "${SCOPE}" in
    unit)
        run_robot tests/unit
        ;;
    integration)
        run_robot --exclude live-api tests/integration
        ;;
    system)
        run_robot tests/system
        ;;
    live-api)
        run_robot --include live-api tests/integration/listing_extractor_live_api.robot
        ;;
    all)
        run_robot --exclude live-api tests/unit tests/integration tests/system
        ;;
    *)
        echo "Unknown scope '${SCOPE}'. Use: unit | integration | system | live-api | all" >&2
        exit 2
        ;;
esac
