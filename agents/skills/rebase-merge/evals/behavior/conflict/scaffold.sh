#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../_lib/sandbox.sh"
sandbox_repo
sandbox_advance_main feature.txt "v2 from main"
