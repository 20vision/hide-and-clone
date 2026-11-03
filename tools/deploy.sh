#!/bin/bash
# Publishes build/ plus the models to GitHub Pages (only game files change after the first push).
cd "$(dirname "$0")/.."; D=$(mktemp -d); git clone -q --depth 1 -b gh-pages https://github.com/20vision/hide-and-clone.git "$D"
cp -L build/index.* web_extra/hero.mp4 store/privacy.html "$D"/; rsync -a --delete web_extra/t/ "$D"/t/; cd "$D"; git add -A >/dev/null
git -c user.name="$(git config --global user.name)" commit -qm "Deploy web build

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git push -q origin gh-pages; cd - >/dev/null; rm -rf "$D"
