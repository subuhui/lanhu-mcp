# Lanhu MCP v1.8.5

This release makes long Axure requirement pages easier for multimodal models to read while preserving the screenshot behavior that existing users already rely on.

## What changes

`lanhu_get_ai_analyze_page_result(mode="full")` still returns the established full-page screenshot at its original path and resolution. When the visible page is large enough that text would become difficult to read as one image, the response also includes overlapping source-resolution detail tiles. Every visual is preceded by a text label containing the page name, image type, tile ID, and source-page coordinates.

The first four detail tiles are returned by default. Use `tile_offset` to continue from the reported next offset and `tile_limit` to request between 1 and 12 tiles per page. Normal pages remain single-image responses, and `text_only` still returns no screenshots.

Tile boundaries are selected near whitespace when the rendered geometry permits it. A 128-pixel overlap keeps arrows, tables, labels, and controls visible across seams. This does not depend on layer names.

## Compatibility and failure behavior

The main screenshot continues to use the existing Playwright `full_page=True` or visible-content crop path. Detail tiles are additive and use Chrome DevTools `Page.captureScreenshot` with `captureBeyondViewport`; the page is briefly scrolled to each requested region to wake ordinary lazy or scroll-triggered content.

If a detail tile cannot be generated, the page still succeeds with the full screenshot and reports the failed tile IDs. Independent virtualized or nested scrolling containers may still require source-specific handling because content outside their own scrollport might not exist in the rendered DOM.

Screenshot cache schema 3 records tile plans and files. The first full-mode request after upgrading rebuilds screenshot metadata once; later calls for the same document version and tile range use the cache.

## Validation

- All 211 offline regression tests passed.
- A forced DevTools failure verified that tile generation cannot discard a usable full screenshot.
- On an authorized live three-page Axure document, the long-page main PNG produced by v1.8.4 and v1.8.5 was pixel-identical at 1920×3683. The enhanced response added four readable detail PNGs.
- The public FastMCP call returned five ordered `image/png` content blocks with matching labels and source coordinates. The cached call completed in 0.752 seconds in that sample.
- Local cold rendering of the same long page took 2.495 seconds on v1.8.4 and 2.934 seconds with four detail tiles, an observed increase of 0.439 seconds on that machine.

These timings describe one validation sample, not a general performance guarantee.
