#!/usr/bin/env bash
#
# Run the server locally with no amplifier attached, using the mock transport.
# Serves the API and web UI at http://localhost:8001.
#
set -euo pipefail
export USE_MOCK_CONTROLLER=true
swift run Run
