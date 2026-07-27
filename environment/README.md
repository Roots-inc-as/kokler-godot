# KOKLER Environment Foundation

This folder holds the shared, assetless environment language for the 2.5D prototype.

Current tracked foundation:

- `materials/`: shared palette materials used by procedural rooms and props.

Planned modular folders:

- `modules/`: floor, wall, corridor, doorway, and column module scenes.
- `props/`: reusable prop scenes with consistent visual/collision rules.
- `landmarks/`: distinct room landmarks such as Root Arch and Broken Survey Table.
- `decals/`: lightweight route marks, scratches, stains, and doorway traces.
- `vfx/`: restrained root growth, dust, spore, and corruption feedback.

Environment scale rules:

- One Godot unit is treated as roughly one meter.
- Current playable rooms stay near 8-20 units wide.
- Door clearances must remain wider than the player dash lane.
- Major blocking props should use simple box/cylinder collision.
- Small floor details, chalk, paper, rope, and tiny debris should remain collisionless.

Visual priority:

1. Player and enemy readability.
2. Doorway and route readability.
3. Interactive object readability.
4. Room identity.
5. Decorative density.

## KayKit layer 1-2 sample

Katman 1 and Katman 2 can optionally add KayKit stone-dungeon models over the
existing procedural room walls. The package has no dedicated Katman 1 wall
FBX, so both layers intentionally reuse the wall, corner, and doorway models
from `Katman2_TasZindan`. The source FBX files and their shared atlas are kept
under `res://assets/kaykit/`; `dungeon_texture.png` remains the atlas used by
the imported models and is not wired into the flat-colour triplanar materials.

- Toggle each layer independently with `enable_kaykit_layer1_walls` and
  `enable_kaykit_layer2_walls` on the dungeon manager. Katman 1 KayKit walls
  default to off while the cave prototype is enabled.
- Scale, orientation, tiling, corners, and doorway fitting are centralized in
  `res://scripts/environment/kaykit_layer_wall_visuals.gd`.
- Existing primitive `StaticBody3D` walls remain the collision source.
- Imported FBX scenes are visual-only and receive no generated collision.
- Corridors intentionally retain their current primitive fallback in this
  first integration pass.
- A missing model or texture leaves the original flat-colour wall visible.

The supplied package contains `OKUBENI.txt`, but no formal licence or
attribution file was present. Verify the applicable KayKit licence before
publishing or redistributing these assets.

## Mines and Caves Katman 1 prototype

`enable_layer1_cave_prototype` applies the CC0 Mines and Caves visuals only to
the Wake Chamber and one deterministically selected connected corridor.
Every other Katman 1 room and corridor keeps the existing primitive fallback.

- Wall, floor, entrance, corner, and rock fitting is centralized in
  `res://scripts/environment/layer1_cave_visuals.gd`.
- Imported scenes are sanitized to visual meshes; package collision resources
  are not included in the runtime scenes.
- Existing procedural wall collision, room openings, navigation, and corridor
  layout remain authoritative.
- Model materials keep their original diffuse, roughness/AO, and normal maps.
- Turning the prototype off restores the original primitive visuals.
- Licence and source details are recorded in
  `res://assets/third_party/mines_and_caves/LICENSE.md`.
