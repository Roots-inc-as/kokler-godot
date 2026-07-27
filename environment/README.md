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
