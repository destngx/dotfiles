#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../_lib/sandbox.sh"
sandbox_repo
printf "wip\n" >wt/notes.txt
