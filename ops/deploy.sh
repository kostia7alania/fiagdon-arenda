#!/usr/bin/env bash
set -euo pipefail
umask 022
base=/srv/fiagdon-arenda
repo="$base/repository"
sha="${1:-}"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected a full commit SHA' >&2; exit 64; }
exec 9>"$base/deploy.lock"
flock -w 300 9
timeout 180 git -C "$repo" fetch --no-tags origin main
tip="$(git -C "$repo" rev-parse FETCH_HEAD)"
if [[ "$tip" != "$sha" ]]; then
  echo "Skipped superseded commit $sha; main is $tip"
  exit 0
fi
release="$base/releases/$sha"
if [[ ! -d "$release" ]]; then
  stage="$(mktemp -d "$base/releases/.staging-$sha-XXXXXX")"
  trap 'rm -rf -- "${stage:-}"' EXIT
  git -C "$repo" archive "$sha" -- index.html assets google9a06f76199d6f2cb.html privacy.rtf robots.txt sitemap.xml | tar -xf - -C "$stage"
  git -C "$repo" show "$sha:ops/validate.py" | python3 - "$stage"
  mkdir -p "$stage/.well-known"
  python3 - "$stage" "$sha" <<'PY'
import datetime, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
(root / '.well-known/deploy.json').write_text(json.dumps({
    'commit': sys.argv[2],
    'deployed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
}) + '\n')
PY
  find "$stage" -type d -exec chmod 755 {} +
  find "$stage" -type f -exec chmod 644 {} +
  mv "$stage" "$release"
  trap - EXIT
fi
link="$base/.current-$$"
ln -s "releases/$sha" "$link"
mv -Tf "$link" "$base/current"
[[ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commit"])' "$base/current/.well-known/deploy.json")" == "$sha" ]]
echo "Deployed $sha to https://fiagdon-arenda.ru/"
