#!/bin/zsh
# Captures Sandman's window (not the whole screen) to a PNG.
# Usage: screenshot.sh <out.png> [delay seconds]
set -euo pipefail
out=${1:?usage: screenshot.sh <out.png> [delay seconds]}
delay=${2:-0}

window_id() {
  osascript -l JavaScript -e '
  ObjC.import("CoreGraphics");
  const windows = ObjC.deepUnwrap(ObjC.castRefToObject(
    $.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly | $.kCGWindowListExcludeDesktopElements, 0)));
  const main = windows.find(w => w.kCGWindowOwnerName === "Sandman" && w.kCGWindowLayer === 0);
  main ? String(main.kCGWindowNumber) : "";
  '
}

# Right after `open`, the window takes a moment to appear.
window=""
for _ in {1..10}; do
  window=$(window_id)
  [[ -n $window ]] && break
  sleep 0.5
done
if [[ -z $window ]]; then
  echo "Sandman's window isn't on screen. Run open on the app again to show it." >&2
  exit 1
fi
screencapture -x -o -T "$delay" -l "$window" "$out"
echo "$out"
