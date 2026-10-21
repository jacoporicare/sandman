---
name: run-sandman
description: Build and launch the Debug Sandman, create real sleep assertions with caffeinate, and screenshot its window. Use when asked to run, start, try or screenshot Sandman, or to confirm a change to the UI or to how assertions are read and grouped.
---

# Run Sandman

Follow "Trying a change" in AGENTS.md. In Claude Code:

1. Note whether the installed copy is running (`pgrep -f /Applications/Sandman.app`) so you can restore it at the end, then `pkill -x Sandman`.
2. Build Debug with the command in AGENTS.md, then `open build/DerivedData/Build/Products/Debug/Sandman.app`. If the window doesn't come up (it stays hidden when Open at Login is on), `open` it again.
3. Start caffeinate with `run_in_background` so it doesn't hold up the shell: `caffeinate -d -t 60` keeps the display on, `caffeinate -i -t 60` keeps the Mac awake.
4. Capture Sandman's window, then Read the PNG:
   ```bash
   .claude/skills/run-sandman/screenshot.sh <scratchpad>/sandman.png 12
   ```
   The second argument is a delay in seconds. Use 12 or more to see a new assertion as a blocker, or 2 to catch it under Background Activity first. The helper captures only Sandman's window, never the rest of the screen. The menu bar dropdown can't be opened from the shell, but the window's Now tab shows the same list.
5. Compare with `pmset -g assertions`.
6. Clean up: stop any caffeinate you started that is still running, `pkill -x Sandman`, and if the installed copy was running before, `open /Applications/Sandman.app`.
