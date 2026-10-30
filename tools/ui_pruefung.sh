#!/usr/bin/env bash
# Prüft die Oberfläche aller Modi auf Überlappungen, Ränder und abgeschnittenen Text (tools/ui_pruefung.gd).
# Fotografiert jeden Zustand aus SZENEN in jeder Größe, Fundstellen sind im Bild rot umrandet.
# Aufruf: tools/ui_pruefung.sh [--groessen=1280x720,1708x924@85] [--aus=<ordner>] [filter …]
#   filter: nur Szenen, deren Name damit beginnt (z. B. g_ maul_ menu_hub)
# Ausgabe: je Lauf eine Zeile "<szene> <größe>: N Funde", am Ende bericht.md im Ausgabeordner.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
GROESSEN="1280x720,1680x1050,1708x924@85"
AUS=/mnt/project-files/screens/ui-pruefung
FILTER=()
for a in "$@"; do
  case $a in
    --groessen=*) GROESSEN=${a#--groessen=} ;;
    --aus=*) AUS=${a#--aus=} ;;
    *) FILTER+=("$a") ;;
  esac
done

# name|optionen für tools/screenshot.gd
SZENEN=(
  "g_bau|"
  "g_setup|--einstellungen"
  "g_wahl|--runden=2 --phase=wahl --auswahl"
  "g_welle|--runden=3 --phase=welle --warten=3 --auswahl"
  "g_extra|--runden=2 --extra"
  "g_rogue|--runden=3 --roguelike"
  "g_debug|--debug"
  "g_menue|--spielmenue=einstellungen"
  "g_mitspieler|--runden=1 --mitspieler=Anna,Ben,Max"
  "e_bau|--map=eeve --auswahl"
  "e_setup|--map=eeve --einstellungen"
  "e_items|--map=eeve --items --auswahl --lagerwahl=1"
  "e_markt|--map=eeve --items --markt"
  "e_fallen|--map=eeve --fallen --auswahl"
  "e_debug|--map=eeve --debug"
  "e_ende|--map=eeve --ende"
  "m_filialwahl|--szene=maul"
  "m_profi|--szene=maul --profi"
  "m_profil|--szene=maul --profil"
  "m_bau|--szene=maul --filiale=post --sandbox --bauen=h01P,h01R --auswahl=h01R"
  "m_einheit|--szene=maul --filiale=hm --level=2 --einheit"
  "m_welle|--szene=maul --filiale=hm --welle --warten=4"
  "m_debug|--szene=maul --filiale=hm --debug"
  "m_menue|--szene=maul --filiale=hm --spielmenue=einstellungen"
  "r_bau|--map=randgruppen --rasse=kleingarten --bauen=1 --auswahl"
  "r_setup|--map=randgruppen --einstellungen"
  "r_welle|--map=randgruppen --rasse=kleingarten --phase=welle --warten=4 --auswahl"
  "y_bau|--map=youtd --auswahl"
  "y_wuerfel|--map=youtd --wuerfel"
  "menu_hub|--szene=menu"
  "menu_single|--szene=menu --seite=single"
  "menu_history|--szene=menu --seite=history"
  "menu_profil|--szene=menu --seite=profile --reiter=0"
  "menu_profil_tower|--szene=menu --seite=profile --reiter=4"
  "menu_credits|--szene=menu --seite=credits"
  "menu_lobby|--szene=menu --seite=lobby --lobby=Anna,Ben,Max --felder=0,1,1,2"
  "menu_einstellungen|--szene=menu --seite=einstellungen"
  "ed_map|--szene=map_editor"
  "ed_tower|--szene=tower_editor"
)

tools/godot_import.sh
mkdir -p "$AUS"
JOBS=${JOBS:-$(nproc)}
LOGS=$(mktemp -d)

lauf() {  # name optionen größe
  local name=$1 opts=$2 g=$3 size=${3%@*} ui="" tag
  [[ $g == *@* ]] && ui="--ui=${g#*@}"
  tag="${name}_${g/@/_ui}"
  # shellcheck disable=SC2086
  timeout 900 xvfb-run -a -s "-screen 0 ${size}x24" godot --rendering-driver opengl3 --resolution "$size" --path . \
    res://tools/screenshot.tscn -- --ueberlappung --aus="$AUS" --name="$tag" $ui $opts >"$LOGS/$tag.log" 2>&1
  local n
  n=$(grep -c '^UI [a-z]' "$LOGS/$tag.log")
  if grep -q '^BILD' "$LOGS/$tag.log"; then echo "$name $g: $n Funde"; else echo "$name $g: KEIN BILD"; fi
}
LAUFEND=0
for e in "${SZENEN[@]}"; do
  name=${e%%|*}
  if ((${#FILTER[@]})); then
    ok=0; for f in "${FILTER[@]}"; do [[ $name == $f* ]] && ok=1; done
    ((ok)) || continue
  fi
  for g in ${GROESSEN//,/ }; do
    if ((LAUFEND >= JOBS)); then wait -n; LAUFEND=$((LAUFEND - 1)); fi
    LAUFEND=$((LAUFEND + 1))
    lauf "$name" "${e#*|}" "$g" &
  done
done
wait

# Bericht: alle Funde je Bild
{
  echo "# UI-Prüfung $(date +%F)"
  echo
  for f in $(ls "$LOGS"/*.log | sort); do
    tag=$(basename "$f" .log)
    if ! grep -q '^BILD' "$f"; then echo "## $tag: kein Bild"; echo; continue; fi
    funde=$(grep '^UI [a-z]' "$f")
    [[ -z $funde ]] && continue
    echo "## $tag"
    echo
    echo "Bild: $(grep '^BILD' "$f" | head -1 | cut -c6-)"
    echo
    echo "$funde" | sed 's/^UI /- /'
    echo
  done
} >"$AUS/bericht.md"
echo "BERICHT $AUS/bericht.md"
rm -rf "$LOGS"
