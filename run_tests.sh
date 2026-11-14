#!/usr/bin/env sh
# Lance les tests GUT sans affichage. Arguments supplémentaires transmis à GUT,
# par exemple : ./run_tests.sh -gselect=test_crate.gd  ou  -gunit_test_name=push
set -e
cd "$(dirname "$0")"
GODOT_BIN="${GODOT:-}"
if [ -z "$GODOT_BIN" ]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT_BIN=godot
	else
		GODOT_BIN="$HOME/JEUX/GODOT/Godot_v4.7.2-stable_linux.x86_64"
	fi
fi
# Import préalable : les nouvelles classes (`class_name`) doivent être connues.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
exec "$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd "$@"
