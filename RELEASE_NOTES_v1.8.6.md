# Lanhu MCP v1.8.6

This release adds a focused visual lookup path for ambiguous Axure requirements while keeping existing full-page analysis compatible.

## Focused requirement evidence

Use `lanhu_inspect_requirement_region` after `lanhu_get_pages` when a requirement says “这两个字段”, “如下”, “红框处”, or otherwise depends on nearby visual context.

The tool accepts exactly one anchor:

- `query`: matches rendered Axure text. A unique match returns `tight` and `context` images.
- `block_id`: selects one stable `Bxxxx` candidate after a repeated-text query.
- `tile_id`: returns a named long-page strip when the relevant words are baked into an embedded screenshot.
- `x`, `y`, `width`, `height`: captures around an explicit source-page rectangle.

It does not run OCR and does not infer semantics from layer names. Repeated text returns candidate previews so the vision model can choose the correct occurrence. Text inside embedded screenshots remains visual evidence and is reached through a tile or source rectangle.

## Full-width horizontal strips

Long-page detail tiles now keep the complete content width and split only along the vertical axis. The default source strip is at most 960 pixels high with 96 pixels of overlap. This keeps labels, values, table headers, and row cells in the same image. The established full screenshot remains available.

Screenshot cache schema 4 rebuilds tile metadata once after upgrade. `tile_offset` and `tile_limit` continue to paginate long-page strips.

## Validation

- All 216 offline tests passed. A fresh wheel installed from the configured domestic mirror, passed `pip check`, and exposed all 17 tools through a real FastMCP stdio handshake.
- The focused and Axure rendering regression suites cover unique text, repeated text, stable IDs, tile IDs, explicit regions, far nonzero canvas origins, hidden text, and tile-failure fallback.
- An authorized structural audit covered six documents, nine rendered pages, 632 text anchors, and 448 visual elements. A 1600×1100 context crop intersected nearby visible evidence for 632/632 anchors.
- On the 1920×4402 sample used to verify “移除这两个字段，同步移除列表内字段”, the query returned a 960×640 tight crop and a 1600×1100 context crop totaling about 208 KiB. The full screenshot plus four prior detail images was about 1.3 MiB in the same benchmark.
- The new full-width `T002` strip is 1920×960 and contains the instruction and both target fields together.
- Repeated “联运渠道” text returned five separate candidate previews, followed by a successful `block_id` drill-down.

These measurements describe the validation samples, not a general timing guarantee.

## Upgrade

A normal source install should pull the tag, upgrade dependencies, reinstall the package, and restart the MCP client. Docker users must rebuild the image.

For an existing single-file deployment with compatible dependencies, replacing `lanhu_mcp_server.py` is sufficient because the file embeds the matching `lanhu_design` package. No account cookie is stored in the source, wheel, or release assets.
