---
name: install
description: Build a Release Sandman and replace the copy in /Applications with it.
disable-model-invocation: true
---

# Install Sandman

Run the script, which does everything:

```bash
.claude/skills/install/install.sh
```

It builds Release, quits any running Sandman (the Debug build too), copies the app into `/Applications` with `ditto`, and opens it. If the build fails it stops before touching the installed app. When Open at Login is on, the reopened app stays in the menu bar without showing its window.

Report what was installed (the commit, and whether the working tree had uncommitted changes) or the build errors.
