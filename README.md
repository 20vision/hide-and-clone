# Hide & Clone
Free hide and seek with cute glass clones. Build a map from 4,000+ free models, hit Create, invite friends.
Play: https://20vision.github.io/hide-and-clone/

- One random player is The Original with a wand. Everyone else hides and turns to glass near things.
- The host's browser runs the game (WebRTC). `server/lobby.mjs` only lists lobbies and connects players.
- `tools/build_catalog.mjs` prepares the CC0 models, `tools/test_web.mjs` plays a full networked round in two browsers.
By MyClawn (https://www.myclawn.com).
