# Tightrope Walker — Godot port

A Godot 4.7 single-player port of the supplied Roblox game. The balance and stage rules are ported from `TightropeRules.luau`; the main scene uses Grab3D’s stylized elderly man as the walker and Kenney Holiday Kit models as winter decorations, alongside reactive ropes, HUD, snow, birds, and camera. The playable course now uses five detailed rooftop skyscrapers above a city street. The original exported world OBJ and PNG assets remain in `assets/world` as source material.

## Play

Open `project.godot` in Godot 4.7 and run the project. Press **W** to step with the left foot or **O** to step with the right foot; lean with **Q/P**. Release tension with **Space** or **E**, pause with **Escape**, and restart with **R**. During a fall, press **Space** to respawn immediately. The gamepad step button alternates feet automatically.

The run timer stays visible in the top HUD banner from the opening through falls, pause, and the finish screen. The banner always shows W/O stepping and Q/P leaning controls. A Space prompt appears only when Space can release wire tension or respawn after a fall. Reaching a tower checkpoint shows a large, centered `TOWER <number>: <Minigame>` title below the banner.

The first rope section introduces Gust Warning. A flag appears on the side the gust will come from. Press **Q/P** to lean away from the flag during the one-second response window. Leaning toward the flag or missing the response triggers a strong gust that makes the walker fall. Gust Warning remains active on later sections alongside their other interruptions. A fall returns the walker to the last reached tower. The final step opens a win card; **Stargaze** plays the ending camera move.

The four crossings move from blue daylight to orange and pink sunset, purple dusk, and night. The sun descends during the first crossing and sets during the second; the moon rises through the third and fourth. Sky colors, city lighting, fog, and the dark overlay blend when a new stage begins.

The wire tension stage shows a corner gauge with green, yellow, and red ranges. Its needle follows the current tension and drops when the player releases the wire. When the needle reaches the red range at 80%, a countdown bar appears beneath the gauge and shrinks toward the snap point, turning red in its final quarter. The gauge remains visible during the final crossing, where gust warnings, birds, wire tension, and sway all run together. Wind and bird response windows take turns so their cues do not overlap. The gauge uses a [CC0 semicircular HUD asset](https://freegameui.net/assets/gauges/gauge_arc-half_cyber-cyan_01/) as its base.

## Tests

Run the import once on a fresh checkout, then run the tests:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_rules.gd
godot --headless --path . --script res://tests/test_scene.gd
```

The rules test covers path layout, cooldowns, tower transitions, checkpoint behavior, gust warnings, birds, tension, sway, deterministic seeds, and two full successful runs. The scene test checks skyscraper construction, the four sky stages and celestial motion, HUD creation, gust flag placement, and step wiring.

## Source and current limits

The Roblox export supplies meshes and textures but no audio assets, rigged player model, or complete Roblox place. This port uses a [Grab3D elderly man](https://grab3d.com/models/characters/elderly-man/) and has no multiplayer or audio. The imported OBJ has static decoration; ropes are separately rendered and animated by Godot. The existing Luau scripts remain in the sibling `TightropeWalker_RobloxStudio` folder.
