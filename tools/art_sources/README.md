# Retained original art sources

Six original image-generation sources: architecture 7×6, portraits 6×5, events 3×4,
decorations/landforms 6×6 (0.2), niyazov_story 3×4 and niyazov_heraldry (0.3).
All are original project paintings, CC0. No third-party game artwork is used.

`../atlas_extract.py` extracts alpha-connected silhouettes; `../reforge_assets.py`
normalizes material colours and pixel grids. Its leaf-pigment pass preserves timber,
stone and wheat. `../niyazov_art.py` prepares story scenes, crest and standard.
`palette_v0_2.json` retains the previous material ramps for comparison.

Reproduce with Python/Pillow: `python3 tools/generate_assets.py`, followed by
`python3 tools/bake_world.py`. The current output is 260 game PNG plus service catalogues.
`baseline_assets.json` and `legacy_generator_v0_1.py` retain the historical 0.1 workshop.
