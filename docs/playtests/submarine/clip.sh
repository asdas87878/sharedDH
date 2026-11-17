#!/bin/sh
# Frames of the Studio window for a clip: clip.sh <out_dir> <seconds> [interval]
# (niri screenshots the window wherever it is; the clipboard's text is put back after)
out=$1; secs=$2; every=${3:-0.2}
mkdir -p "$out"
id=$(niri msg -j windows | python3 -c "import json,sys; w=[x for x in json.load(sys.stdin) if 'RideAFish' in (x.get('title') or '') or 'Roblox Studio' in (x.get('title') or '')]; w.sort(key=lambda x:-x['layout']['window_size'][0]*x['layout']['window_size'][1]); print(w[0]['id'])")
clip=$(wl-paste -n -t text/plain 2>/dev/null)
end=$(( $(date +%s) + secs )); i=0
while [ $(date +%s) -lt $end ]; do
  niri msg action screenshot-window --id "$id" --path "$out/f$(printf %04d $i).png" >/dev/null 2>&1
  i=$((i+1)); sleep "$every"
done
[ -n "$clip" ] && printf %s "$clip" | wl-copy
echo "$i frames"
