#!/bin/zsh
# Builds a Release Sandman and replaces the copy in /Applications with it.
set -euo pipefail
cd "$(git -C "${0:A:h}" rev-parse --show-toplevel)"

xcodebuild -project Sandman.xcodeproj -scheme Sandman -configuration Release -derivedDataPath build/DerivedData -quiet build

# Quit every running copy, so the new one isn't a second bulb in the menu bar.
pkill -x Sandman || true
for _ in {1..50}; do
  pgrep -x Sandman >/dev/null || break
  sleep 0.2
done
if pgrep -x Sandman >/dev/null; then
  echo "Sandman didn't quit; the installed app is unchanged." >&2
  exit 1
fi

ditto build/DerivedData/Build/Products/Release/Sandman.app /Applications/Sandman.app
open /Applications/Sandman.app
echo "Installed $(git rev-parse --short HEAD)$(git diff --quiet HEAD -- Sandman Sandman.xcodeproj || echo ' with uncommitted changes')"
