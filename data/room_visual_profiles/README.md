# Room Visual Profiles

These resources separate room presentation from room gameplay.

The existing dungeon generator still owns:

- room graph generation
- enemy spawning
- key and exit placement
- combat gates
- rewards
- minimap state

Visual profiles currently provide:

- floor material
- wall material
- density hints for later prop placement
- root/fungal density hints
- lighting profile names for future lighting passes

Do not move critical path or softlock logic into these resources.
