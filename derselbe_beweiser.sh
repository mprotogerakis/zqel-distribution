#!/bin/sh
# Ist der ausgelieferte Beweiser derselbe wie der aus dem gepinnten Rad?
#
#   sh tools/derselbe_beweiser.sh <ausgeliefert.dylib> <aus-dem-rad.dylib>
#
# WOZU (#538):
# Der Pin in z3-pin.json nennt den sha256 der libz3, WIE SIE AUS DEM RAD
# KOMMT. Ein ausgeliefertes macOS-Paket muss aber signiert sein - sonst
# lehnt Apples Notardienst es ab, und zwar jedes einzelne Mach-O darin
# (gemessen am 2026-09-19: 58 Objekte, 117 Meldungen). Signieren schreibt
# die Datei um:
#
#     aus dem Rad (adhoc, linker-signed)   edf75c4ced3d7ab3
#     mit Developer ID signiert            117a4682d7a7d17b
#
# Der Rueckweg ist zu: `codesign --remove-signature` nimmt auch die
# urspruengliche Linker-Signatur mit, und eine neu gesetzte faellt anders
# aus. Gemessen, alle drei Wege.
#
# WAS TROTZDEM GEHT, und das ist der Gegenstand dieses Skripts: signieren
# ruehrt NUR an, was die Signatur beschreibt. Gemessen an denselben zwei
# Dateien:
#
#     8 abweichende Bytes von 27 369 664 vor der Signatur (99,999971 %)
#     alle acht in zwei Ladebefehlen:
#       LC_SEGMENT_64 __LINKEDIT   die Segmentgroesse
#       LC_CODE_SIGNATURE          die Groesse der Signatur
#
# Code, Daten und Symbole sind unberuehrt. Dieses Skript prueft genau das:
#
#     alles NACH den Ladebefehlen bis zum Beginn der Signatur
#     muss byteweise gleich sein.
#
# Die Ladebefehle selbst bleiben aussen vor - dort und nur dort stehen die
# Groessenfelder, die sich aendern DUERFEN. Sie zu vergleichen hiesse, die
# Signatur mitzuvergleichen.
#
# WARUM ALS SHELL-SKRIPT: wer das nachrechnen will, soll nichts installieren
# und nichts glauben muessen. otool, dd und shasum liegen auf jedem Mac.
set -eu

if [ $# -ne 2 ]; then
  echo "Aufruf: $0 <ausgeliefert.dylib> <aus-dem-rad.dylib>" >&2
  exit 2
fi
A=$1; B=$2
for f in "$A" "$B"; do
  [ -f "$f" ] || { echo "nicht da: $f" >&2; exit 2; }
done

# Ende der Ladebefehle = 32 (Mach-O-64-Kopf) + sizeofcmds.
# `otool -h` druckt es; die letzte Zahlenzeile traegt sizeofcmds an Stelle 6.
kopf_ende() {
  # `otool -h` druckt magic als Hex - ein numerischer Filter greift daneben.
  # Die Datenzeile ist die, die mit 0xfeedfac* beginnt; sizeofcmds ist Feld 7.
  szcmds=$(otool -h "$1" | awk '/^[ \t]*0xfeedfac/ {print $7; exit}')
  [ -n "$szcmds" ] || { echo "sizeofcmds nicht lesbar: $1" >&2; exit 3; }
  echo $((32 + szcmds))
}

# Beginn der Signatur = dataoff des LC_CODE_SIGNATURE.
sig_beginn() {
  off=$(otool -l "$1" | awk '/LC_CODE_SIGNATURE/{f=1} f&&/dataoff/{print $2; exit}')
  if [ -z "$off" ]; then
    # Unsigniert: dann ist der Vergleichsbereich alles bis zum Dateiende.
    wc -c < "$1" | tr -d ' '
  else
    echo "$off"
  fi
}

ea=$(kopf_ende "$A"); eb=$(kopf_ende "$B")
sa=$(sig_beginn "$A"); sb=$(sig_beginn "$B")

echo "  $A"
echo "    Ladebefehle enden bei $ea, Signatur beginnt bei $sa"
echo "  $B"
echo "    Ladebefehle enden bei $eb, Signatur beginnt bei $sb"

# NICHT NUR DIE HASHES VERGLEICHEN, SONDERN AUCH DIE GRENZEN. Zwei Dateien,
# deren Vergleichsbereiche verschieden lang sind, sind nicht dasselbe
# Programm - ein Hash ueber verschieden lange Stuecke saehe nur anders aus
# und sagte nicht, warum.
if [ "$ea" != "$eb" ] || [ "$sa" != "$sb" ]; then
  echo "  VERSCHIEDEN: die Bereiche liegen nicht an derselben Stelle" >&2
  exit 1
fi

laenge=$((sa - ea))
[ "$laenge" -gt 0 ] || { echo "  leerer Vergleichsbereich - das misst nichts" >&2; exit 3; }

ha=$(dd if="$A" bs=1 skip="$ea" count="$laenge" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
hb=$(dd if="$B" bs=1 skip="$eb" count="$laenge" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)

echo "  verglichen: $laenge B (Code, Daten, Symbole - ohne Ladebefehle, ohne Signatur)"
echo "    $ha"
echo "    $hb"
if [ "$ha" = "$hb" ]; then
  echo "  DERSELBE BEWEISER: was gerechnet wird, ist byteweise dasselbe."
  echo "  Die Dateien unterscheiden sich nur in ihrer Signatur und in den"
  echo "  Groessenfeldern, die sie beschreiben."
  exit 0
fi
echo "  VERSCHIEDEN: der ausgelieferte Beweiser ist nicht der aus dem Rad." >&2
exit 1
