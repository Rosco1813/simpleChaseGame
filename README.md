# SimpleChase (Godot 4.4.1)

Minimal, annotated top‑down chase prototype – designed to be easy to extend and debug.

## Features
- Player movement using default `ui_*` actions (Arrow Keys / WASD).
- Enemies that seek the player but stop at a safe distance (`stop_distance`).
- Spawner that periodically creates enemies around the player (uniform circle distribution) with clamped in‑bounds positioning (`spawn_margin`).
- World bounds (`GameConfig.world_rect`) + physical wall colliders + visible border line.
- Simple colored `Polygon2D` placeholders (no external art needed).
- Clean separation of scenes & scripts for quick iteration.

## Project Structure
```
scenes/
  Main.tscn        # Root scene (walls, border, spawner, player, camera)
  Player.tscn      # Player character scene (square + collision)
  Enemy.tscn       # Enemy character scene (square + collision + stop distance)
scripts/
  player.gd        # Movement + clamping to world rect
  enemy.gd         # Chase logic + stop distance + clamping
  spawner.gd       # Timed spawning (radius, margin, max count)
  game_config.gd   # Autoload singleton storing world_rect
assets/            # (Put art/audio here later)
project.godot      # Project config + autoload
```

## Input Map
Godot already has ui_left/right/up/down. If not, add them in Project Settings > Input Map and assign arrow keys & WASD.

## Extending
- Health: add `@export var health := 3` to player & enemies; reduce on hit; free enemy on <= 0.
- Damage radius: add an `Area2D` child with a `CollisionShape2D` on player for melee or pickup detection.
- Scoring: create a `GameState` autoload or use `GameConfig` to track score; increment when enemy dies.
- Art: replace `Polygon2D` with `Sprite2D` or `AnimatedSprite2D` (keep collision shapes sized correctly).
- Difficulty scaling: gradually reduce `spawn_interval` or raise `max_enemies` over time.
- Camera shake: on events, call `Camera2D.add_trauma()` if you add a simple shake script.
- UI: add a `CanvasLayer` scene for health bar, score, debug text.

## Running
1. Open folder in Godot 4.4.1.
2. Ensure autoload: Project Settings > Autoload: `scripts/game_config.gd` as `GameConfig` (already configured in `project.godot`, just verify).
3. Press Play (F5). Move with Arrow Keys / WASD.
4. Enemies spawn around player, stay within border, and halt at `stop_distance`.

## Key Tunable Exports (select nodes to edit in Inspector)
Player (`Player.tscn`): `speed`
Enemy (`Enemy.tscn`): `speed`, `stop_distance`
EnemySpawner (in `Main.tscn`): `spawn_interval`, `max_enemies`, `spawn_radius`, `spawn_margin`, `enemy_scene`, `player_path`
GameConfig (autoload): `world_rect` (playable area size & position)

## World Bounds & Walls
`GameConfig.world_rect` defines the logical clamp area. Physical walls (StaticBody2D) in `Main.tscn` prevent leaving. If you resize `world_rect`, also resize/ reposition the four wall shapes & `Line2D` border for consistency.

Recommended workflow for resizing play area:
1. Decide new half-width / half-height (e.g. 640x360 for 1280x720 total).
2. Update `world_rect` size to (2*half_width, 2*half_height) and position to (-half_width, -half_height).
3. Adjust wall RectangleShape2D sizes & positions (top/bottom at +/- (half_height + wall_thickness/2), left/right at +/- (half_width + wall_thickness/2)).
4. Update `Line2D.points` to the four corners (closing back to first point).

## Spawn Logic
Spawner picks a random angle, radius (sqrt distribution) around player, then clamps inside `world_rect` minus `spawn_margin`. Increase `spawn_margin` if enemies appear to overlap the border.

## Debugging Tips
- Nothing renders: Ensure Player & Enemy scenes still have `Polygon2D` nodes or assigned textures.
- Enemies not moving: Check their `target_path` (Spawner sets it); select an enemy during runtime and verify `target_path` is valid.
- Enemies spawning outside: Increase `spawn_margin` or confirm `GameConfig.world_rect` matches wall interior.
- Player/enemies slipping outside walls: Confirm their `CollisionShape2D` radii fit fully inside and walls are positioned correctly. Enable Debug > Visible Collision Shapes in the Godot editor to visualize.
- Performance dips: Lower `max_enemies` or increase `spawn_interval`.
- Autoload missing errors: Re-add `game_config.gd` in Project Settings > Autoload (name must match `GameConfig`).
- Clamp not working: Make sure `_world_rect` is non-zero: print `GameConfig.world_rect` in `_ready()` if needed.

## Common Extension Patterns
- Centralized signals: Have `GameConfig` (or a new `GameEvents` autoload) emit signals like `enemy_spawned(enemy)` or `enemy_defeated(enemy)`.
- Object pooling: Replace `instantiate` with a pool for performance if many spawns per second.
- Difficulty curve: Use a Timer to periodically modify spawner exports.

## Troubleshooting Checklist
1. Open `Main.tscn`; verify child nodes: Player, EnemySpawner, Walls, Border.
2. Run with Visible Collision Shapes to inspect walls & collision radii.
3. Select `GameConfig` in the running scene tree (Remote tab) to inspect `world_rect` live.
4. Pause (F7) and inspect an enemy's `global_position` vs wall coordinates if stuck.

## License / Usage
This template is intentionally simple; feel free to reuse or modify freely.

---
Need a next feature (combat, pickups, score, waves)? Add an issue or ask for guidance.
