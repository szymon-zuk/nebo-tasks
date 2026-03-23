#!/usr/bin/env bash
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$D/bootstrap-db.sh"
"$D/load-sample-data.sh"
"$D/run-queries.sh"
"$D/backup.sh"
