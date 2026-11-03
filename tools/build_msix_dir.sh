#!/bin/bash
# Exports the Windows build and lays out build/msix for makeappx (models and thumbnails go to gamedata/).
set -e; cd "$(dirname "$0")/.."; G=~/.local/godot/Godot_v4.7.2-stable_linux.x86_64
mkdir -p build/win; timeout 300 nice -n 5 "$G" --headless --path . --export-release Windows build/win/HideAndClone.exe 2>&1 | grep -E 'ERROR|SCRIPT' | head || true
rm -rf build/msix; mkdir -p build/msix/gamedata; cp build/win/* build/msix/; cp -r store/msix/* build/msix/; cp LICENSE CREDITS.md build/msix/
cp -rL web_extra/a web_extra/t build/msix/gamedata/; for n in cocktail glass-wine wine-red wine-white; do rm -f build/msix/gamedata/a/food-kit/$n.glb build/msix/gamedata/t/food-kit/$n.png; done; du -sh build/msix; find build/msix -type f | wc -l
tar -C build -cf build/msix.tar msix
