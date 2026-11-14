# Tightrope Walker — Godot port

A Godot 4.7 single-player port of the supplied Roblox game. The balance and stage rules are ported from `TightropeRules.luau`; the main scene builds the walker, reactive ropes, HUD, snow, birds, and camera. The original exported world OBJ has been split into 21 parts because Godot limits the number of surfaces in one mesh. The OBJ and PNG assets remain editable in `assets/world`.

## Play

Open `project.godot` in Godot 4.7 and run the project. Lean with **A/D** or **Left/Right**, step with **W** or **Up**, release tension with **Space** or **E**, pause with **Escape**, and restart with **R**. Gamepad buttons and touch controls are supported through the HUD and Input Map.

The four towers challenge wind, birds, tension, and sway. A fall returns the walker to the start of the current tower. The final step opens a win card; **Stargaze** plays the ending camera move.

## Tests

Run the import once on a fresh checkout, then run the tests:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_rules.gd
godot --headless --path . --script res://tests/test_scene.gd
```

The rules test covers path layout, cooldowns, tower transitions, checkpoint behavior, birds, tension, sway, deterministic seeds, and two full successful runs. The scene test checks world import, HUD creation, and step wiring.

## Source and current limits

The Roblox export supplies meshes and textures but no audio assets, rigged player model, or complete Roblox place. This port uses a Godot capsule walker and has no multiplayer or audio. The imported OBJ has static decoration; ropes are separately rendered and animated by Godot. The existing Luau scripts remain in the sibling `TightropeWalker_RobloxStudio` folder.
