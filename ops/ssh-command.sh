#!/usr/bin/env bash
set -euo pipefail
if [[ "${SSH_ORIGINAL_COMMAND:-}" =~ ^deploy\ ([0-9a-f]{40})$ ]]; then
  exec /usr/local/lib/fiagdon-arenda/deploy.sh "${BASH_REMATCH[1]}"
fi
echo 'Only deploy <40-character commit SHA> is allowed' >&2
exit 64
