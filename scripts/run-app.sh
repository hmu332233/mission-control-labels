#!/bin/zsh
# Local dev helper for the `dev` branch (build + restart + what to check).
# Not part of any pull request.
#
#   scripts/run-app.sh                      release build, started with `open`
#   scripts/run-app.sh debug                debug build
#   scripts/run-app.sh release foreground   start from this shell instead of `open`
#
# `foreground` inherits this terminal's Accessibility permission, so no need to
# re-grant it after a rebuild. Use it when the menu bar says "State: No Permission".
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
MODE="${2:-open}"
APP="build/MissionControlLabels.app"
LOGS=~/Library/Logs/MissionControlLabels

./scripts/build-app.sh "$CONFIG"
pkill -f "${APP}/Contents/MacOS/MissionControlLabels" && sleep 0.5 || true

if [[ "$MODE" == foreground ]]; then
  "${APP}/Contents/MacOS/MissionControlLabels" &
  echo "started from this shell: pid=$!"
else
  open "$APP"
  echo "started with open"
fi

cat <<NOTE

checklist
  open Mission Control:   open -a "Mission Control"   (Esc closes it)
  menu bar item           "State: Showing" while Mission Control is open
  no labels at all        "State: No Permission" → System Settings → Privacy & Security →
                          Accessibility → remove "Mission Control Labels", add it again.
                          Every rebuild changes the ad-hoc signature, so the grant does not survive it.
  something looks wrong   menu bar → "Record Next Mission Control Diagnostics", then open
                          Mission Control; the report lands in ${LOGS}
NOTE
