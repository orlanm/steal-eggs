#!/bin/zsh

PROJECT_DIR="/Users/orlan/Desktop/steal eggs"
ROJO_PORT=34873
ROJO_BIN="/Users/orlan/.rokit/bin/rojo"
CURSOR_APP="/Applications/Cursor.app"
CURSOR_CLI="$CURSOR_APP/Contents/Resources/app/bin/cursor"
STUDIO_APP="/Applications/RobloxStudio.app"

cd "$PROJECT_DIR" || exit 1

is_rojo_running() {
  lsof -iTCP:"$ROJO_PORT" -sTCP:LISTEN -t >/dev/null 2>&1
}

if is_rojo_running; then
  :
else
  osascript <<APPLESCRIPT
tell application "Terminal"
  set rojoTab to do script "cd '$PROJECT_DIR' && '$ROJO_BIN' serve"
  delay 0.3
  set miniaturized of (window of rojoTab) to true
end tell
APPLESCRIPT
fi

"$CURSOR_CLI" "$PROJECT_DIR" --classic
/usr/bin/open "$STUDIO_APP"
