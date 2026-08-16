#!/usr/bin/env bash
# Applies (or removes) the Todoist toggle keybind in ~/.config/hypr/bindings.lua.
# Always backs up first and rolls back automatically if the reload errors.
set -euo pipefail

COMBO="${1:?usage: set-keybind.sh \"CTRL + SUPER + Y\" | __REMOVE__}"
FILE="$HOME/.config/hypr/bindings.lua"
MARKER='omarchy-shell shell toggle io.github.aryan-techie.todoist'

if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE not found" >&2
  exit 2
fi

BACKUP="$FILE.bak.$(date +%s)"
cp "$FILE" "$BACKUP"

if [ "$COMBO" = "__REMOVE__" ]; then
  grep -vF "$MARKER" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
elif grep -qF "$MARKER" "$FILE"; then
  awk -v marker="$MARKER" -v combo="$COMBO" '
    index($0, marker) {
      sub(/o\.bind\("[^"]*"/, "o.bind(\"" combo "\"")
    }
    { print }
  ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
else
  printf 'o.bind("%s", "Toggle Todoist", "%s")\n' "$COMBO" "$MARKER" >> "$FILE"
fi

hyprctl reload >/dev/null

ERRS="$(hyprctl configerrors)"
if [ -n "$ERRS" ]; then
  cp "$BACKUP" "$FILE"
  hyprctl reload >/dev/null
  echo "ERROR: $ERRS" >&2
  exit 1
fi

echo "OK: $COMBO"
