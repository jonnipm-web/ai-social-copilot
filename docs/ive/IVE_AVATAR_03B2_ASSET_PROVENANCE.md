# IVE Avatar — 03B2 Asset Provenance

**Mission:** IVE-AVATAR-RIVE-ASSET-03B2
**Ingestion date:** 2026-09-13
**Origin:** Visual assets generated in ChatGPT and explicitly approved by Paulo.
**Original source directory:** `G:\Meu Drive\Aplicativo copiloto\`

## Asset A — Master Portrait

- **Original filename found in source directory:** `Imagem do Codex 13 de set. de 2026, 14_43_14.png`
- **Canonical repo path:** `assets/ive/source/ive_avatar_master_03b2.png`
- **Dimensions:** 1254 x 1254
- **Color mode:** RGBA (8-bit)
- **Transparency status:** Real alpha channel. Corner pixels sampled at (0,0), fully transparent
  (RGBA `0,0,0,0`); center/face region sampled at near-full opacity (alpha ≈ 253). Not a
  rasterized checkerboard — verified via Pillow alpha histogram inspection this session.
- **SHA-256 (original, `G:\Meu Drive\Aplicativo copiloto\...`):**
  `a30ec1aef41d715f28a993be5149298ad2987b5f989b25d28f2d363980763e13`
- **SHA-256 (repo copy, `assets/ive/source/ive_avatar_master_03b2.png`):**
  `a30ec1aef41d715f28a993be5149298ad2987b5f989b25d28f2d363980763e13`
- Byte-identical copy confirmed (no recompression, resize, conversion, or edit applied).

## Asset B — Character Production Pack

- **Original filenames found in source directory** (two identical copies saved under different
  automatic names):
  - `8114d7d3-8519-4c52-b224-09c91329b6a4.png`
  - `Imagem do Codex 13 de set. de 2026, 14_42_09.png`
- **Canonical repo path:** `assets/ive/source/ive_character_production_pack_03b2_v1.png`
- **Dimensions:** 1536 x 1024
- **Color mode:** RGBA (8-bit)
- **Transparency status:** RGBA with alpha present throughout — not a fully opaque flat sheet.
  Measured alpha extrema (0, 253): 0.82% of pixels (12,879) are fully transparent (alpha = 0,
  concentrated at the rounded/faded corners of the sheet), and no pixel reaches full opacity
  (alpha = 255) — sampled interior pixels (portrait area, panel background) sit around
  alpha ≈ 250–253. Functionally this reads as an opaque technical reference sheet when viewed
  normally, but the alpha channel is not uniformly 255 and should not be described as
  "opaque"/"not applicable" without qualification. This is a flattened raster reference sheet,
  not an isolated character cutout — do not treat its background as intentionally transparent
  for compositing purposes.
- **SHA-256 (both original filenames, identical):**
  `307f037ecd6dad0410c077d79aafd7cda71f9e5df22303cbce973d3b77a8ae02`
- **SHA-256 (repo copy, `assets/ive/source/ive_character_production_pack_03b2_v1.png`):**
  `307f037ecd6dad0410c077d79aafd7cda71f9e5df22303cbce973d3b77a8ae02`
- Byte-identical copy confirmed (no recompression, resize, conversion, or edit applied).
- Internally labeled "ASSET 03B2 · v1.0" and contains: master portrait, expression references
  (idle, listening, thinking, speaking, success, warning, opportunity; attentive/executive
  marked as not yet produced), turnaround views, component/layer breakdown, mouth shapes, eye
  states, color palette, materials/style notes, and technical specifications referencing
  `IVE_AVATAR_COMPACT`, `IVE_EXECUTIVE_STATE_MACHINE`, `stateIndex` (0–9), `isThinking`,
  `isSpeaking`.

## Relation to `assets/ive/reference/ive_character_reference.png`

That file is the **original V1 reference/specification sheet** (1536x1024, RGB, no alpha,
SHA-256 `6ebbf2ffcb22a32ab95126384ca728fc95ba803f9c2aa759d2b69507fd6888e2`). It is a distinct,
earlier artifact and was **not modified** by this ingestion — confirmed unchanged
(hash re-verified at ingestion time, matches pre-ingestion value). Assets A and B above are
new, later, and distinct from it (all three SHA-256 values differ).

## Statement

- Original V1 reference preserved unchanged.
- Assets A and B are copies of files provided by Paulo; no visual editing, recompression, or
  format conversion was performed.
- Purpose: production source/reference material for Rive authoring (03B3).
- This PNG pair is **not** an SVG and does not contain editable vector layers.
- The Character Production Pack (Asset B) does **not** contain editable layers — it is a
  flattened raster reference sheet.
- No `.riv` file exists as a result of this ingestion. `assets/ive/rive/ive_executive_v1.riv`
  remains unauthored.
