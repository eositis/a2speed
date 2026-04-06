#!/usr/bin/env bash
# Bump build number only (not product version), update build date, and sync metadata
# across applesoft/A2SPEED.bas, applesoft/README.TXT, and README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION_FILE="$ROOT/VERSION"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "apply-release-metadata.sh: missing $VERSION_FILE" >&2
  exit 1
fi

get_var() {
  local key="$1"
  grep -E "^${key}=" "$VERSION_FILE" | head -1 | cut -d= -f2-
}

VER="$(get_var A2SPEED_VERSION)"
LAST="$(get_var A2SPEED_BUILD)"
# shellcheck disable=SC2004
NEXT=$((LAST + 1))
DATE="$(date +%Y-%m-%d)"

{
  echo "# a2speed — version is edited manually; build number is advanced by scripts/apply-release-metadata.sh (e.g. via \`make disk\`)."
  echo "A2SPEED_VERSION=$VER"
  echo "A2SPEED_BUILD=$NEXT"
} > "${VERSION_FILE}.tmp"
mv "${VERSION_FILE}.tmp" "$VERSION_FILE"

# Title line: version and build appended to "A2SPEED - Apple II Benchmarks (Applesoft) ..."
perl -0777 -i -pe \
  's/PRINT "A2SPEED - Apple II Benchmarks \(Applesoft\)[^"]*"/PRINT "A2SPEED - Apple II Benchmarks (Applesoft) v'"${VER//\//\\/}"' build '"$NEXT"'"/g' \
  "$ROOT/applesoft/A2SPEED.bas"

perl -i -pe 's/^Version: .*/Version: '"$VER"'/' "$ROOT/applesoft/README.TXT"
perl -i -pe 's/^Build Date: .*/Build Date: '"$DATE"'/' "$ROOT/applesoft/README.TXT"
perl -i -pe 's/^Build Number: .*/Build Number: '"$NEXT"'/' "$ROOT/applesoft/README.TXT"

if grep -q '^\*\*Release:\*\* v' "$ROOT/README.md"; then
  perl -i -pe \
    's/^\*\*Release:\*\* v[\d.]+ · build \d+ · \d{4}-\d{2}-\d{2}/**Release:** v'"$VER"' · build '"$NEXT"' · '"$DATE"'/' \
    "$ROOT/README.md"
else
  echo "apply-release-metadata.sh: README.md missing **Release:** line (see template after title)" >&2
  exit 1
fi

echo "Release metadata: v$VER build $NEXT ($DATE)"
