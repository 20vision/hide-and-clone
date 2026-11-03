#!/bin/bash
# Exports the web build and links the model files next to it.
cd "$(dirname "$0")/.."
timeout 200 ~/.local/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --export-release Web build/index.html 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR: .*(script|Script)|res://scripts" | head -20
ln -sfn ../web_extra/hero.mp4 build/hero.mp4; ln -sfn ../web_extra/a build/a; ln -sfn ../web_extra/t build/t
