# Retained original art sources

Four original image-generation atlases: architecture (7×6), portraits (6×5),
events (3×4) and decorations/landforms (6×6). They share the palette, lighting,
material detail and perspective recorded in ART_DIRECTION.md. No downloaded
third-party game artwork is used.

`../atlas_extract.py` separates complete alpha-connected silhouettes, including
padding beyond nominal cells, so neighbouring fragments do not become part of
another sprite. `../reforge_assets.py` normalizes the pixel grid/palette, writes
all 246 game PNGs and builds the manifest/catalog/revision registry. The last two
landforms are source brushes for the baked world, not extra counted game assets.

`baseline_assets.json` records IDs, sizes and SHA-256 of the 136 original assets.
`legacy_generator_v0_1.py` retains the previous workshop for reference; current
reproduction starts with `python3 tools/generate_assets.py`, followed by
`python3 tools/bake_world.py`. The original atlas files are required and included.
