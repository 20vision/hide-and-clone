#!/bin/bash
# Plays the native build with a virtual Xbox pad under Xvfb. Usage: tools/test_native_pad.sh <exe> <outdir> (needs sudo)
EXE=$1; S=$2; export DISPLAY=${DISPLAY:-:77}; cd "$(dirname "$0")/.."
shot(){ ffmpeg -hide_banner -v error -y -f x11grab -video_size 1280x720 -i "$DISPLAY" -frames:v 1 "$S/$1.png"; }
F=$(mktemp -u); mkfifo "$F"; sudo -n python3 tools/fakepad.py < <(tail -f "$F") >/dev/null 2>&1 &
sleep 2; sudo -n chmod 666 "$(ls -t /dev/input/event* | head -1)"
HC_NO_TRACK=1 stdbuf -oL "$EXE" -- --lobby=ws://127.0.0.1:8932 > "$S/pad.log" 2>&1 &
P=$!; sleep 8; shot p0
send(){ echo "$@" > "$F"; sleep 1; }
echo 'a HY 1' > "$F"; sleep .2; echo 'a HY 0' > "$F"; sleep 1; shot p1; send b A; sleep 2; shot p2_create; send b A; sleep 30; shot p3_game; send b Y; sleep 2
echo 'a LY -32000' > "$F"; sleep 2; echo 'a LY 0' > "$F"; echo 'a RX 25000' > "$F"; sleep 1; echo 'a RX 0' > "$F"; shot p4_hide; send b X; send b START; sleep 1; shot p5_menu; send b B; sleep 1; shot p6
grep -E '\[hc\]|ERROR' "$S/pad.log" | cut -c1-150 | head; kill $P; echo q > "$F"; sleep 1; rm -f "$F"
