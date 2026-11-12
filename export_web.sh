#!/usr/bin/env bash
# Exporte le jeu en HTML (Web) dans build/web/.
#
# Usage :
#   ./export_web.sh                 exporte
#   ./export_web.sh --serve [port]  exporte puis sert le résultat en local (port 8000 par défaut)
#   ./export_web.sh --debug         exporte en mode débogage
#
# L'exécutable Godot est pris dans la variable GODOT, sinon dans le PATH
# (godot, godot4), sinon à l'emplacement par défaut ci-dessous.

set -euo pipefail

DEFAULT_GODOT="$HOME/JEUX/GODOT/Godot_v4.7.2-stable_linux.x86_64"
PRESET="Web"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$PROJECT_DIR/build/web"

serve=false
port=8000
mode="--export-release"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--serve)
			serve=true
			if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
				port="$2"
				shift
			fi
			;;
		--debug)
			mode="--export-debug"
			;;
		-h|--help)
			sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*)
			echo "Option inconnue : $1 (voir --help)" >&2
			exit 2
			;;
	esac
	shift
done

# --- Localisation de Godot ---------------------------------------------------
godot="${GODOT:-}"
if [[ -z "$godot" ]]; then
	godot="$(command -v godot || command -v godot4 || true)"
fi
if [[ -z "$godot" && -x "$DEFAULT_GODOT" ]]; then
	godot="$DEFAULT_GODOT"
fi
if [[ -z "$godot" || ! -x "$godot" ]]; then
	echo "Godot introuvable. Indiquez son chemin : GODOT=/chemin/vers/godot $0" >&2
	exit 1
fi

# --- Vérification des modèles d'export ---------------------------------------
# « 4.7.2.stable.official.ed1daf0bf » -> « 4.7.2.stable »
version="$("$godot" --version | cut -d. -f1-4 | sed 's/\.official$//')"
templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version"
if [[ ! -f "$templates/web_nothreads_release.zip" ]]; then
	echo "Modèles d'export Web absents de $templates" >&2
	echo "Installez-les depuis l'éditeur : Éditeur > Gérer les modèles d'export." >&2
	exit 1
fi

# --- Export -------------------------------------------------------------------
echo "Godot  : $godot ($version)"
echo "Sortie : $OUT_DIR"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
if ! "$godot" --headless --path "$PROJECT_DIR" "$mode" "$PRESET" "$OUT_DIR/index.html" >"$log" 2>&1; then
	cat "$log" >&2
	echo "Échec de l'export." >&2
	exit 1
fi
# Godot peut renvoyer 0 malgré une erreur : on vérifie les fichiers produits.
for file in index.html index.js index.wasm index.pck; do
	if [[ ! -s "$OUT_DIR/$file" ]]; then
		cat "$log" >&2
		echo "Échec de l'export : $file manquant." >&2
		exit 1
	fi
done
if grep -qE "^(ERROR|SCRIPT ERROR)" "$log"; then
	echo "Export terminé, mais Godot a signalé des erreurs :" >&2
	grep -E -A1 "^(ERROR|SCRIPT ERROR)" "$log" >&2
fi

echo "Export réussi : $(du -sh "$OUT_DIR" | cut -f1) dans build/web/"

# --- Service local -------------------------------------------------------------
if $serve; then
	echo "Jeu disponible sur http://localhost:$port (Ctrl+C pour arrêter)"
	cd "$OUT_DIR"
	exec python3 -m http.server "$port" --bind 127.0.0.1
else
	echo "Pour tester : ./export_web.sh --serve   (ou : cd build/web && python3 -m http.server 8000)"
fi
