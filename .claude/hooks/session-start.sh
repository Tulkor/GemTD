#!/bin/bash
# Richtet Cloud-Sessions ein: Godot 4.3 und Windows-Exportvorlage, damit Tests und Builds sofort laufen.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

"$CLAUDE_PROJECT_DIR/tools/setup_godot.sh"
# Git-Hook: Tower-Tabelle wird bei Commits mit Tower-Daten automatisch neu erzeugt.
git -C "$CLAUDE_PROJECT_DIR" config core.hooksPath tools/git-hooks
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi
