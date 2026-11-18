# v1.8.4 - Restore fast requirement analysis and reliable browser installation

This patch restores the fast requirement-document behavior users had before v1.8.x and fixes Playwright browser installation through domestic mirrors.

## Requirement document timeout fix

The requirement tools had several latent costs that were not covered by the release tests. `text_only` still scanned every DOM style and captured a full-page PNG, every page waited for `networkidle` plus a fixed two-second delay, the sitemap was requested twice in one analysis call, and a cache hit still contacted Lanhu before returning. Relative `DATA_DIR` values also followed the MCP client's working directory, which could make an existing cache appear missing.

v1.8.4 changes that behavior:

- `text_only` extracts text and annotations without scanning design styles or taking screenshots.
- `lanhu_mcp_server.py` embeds the project-owned `lanhu_design` implementation, so historical single-file deployments can use the full tool set without copying a sidecar package directory. If an optional third-party design dependency is absent, requirement tools still start.
- Axure rendering waits for bounded DOM/page readiness instead of `networkidle` and the fixed delay.
- One fetched sitemap is reused for download and analysis.
- A matching versioned cache can return without any Lanhu request.
- Relative `DATA_DIR` values resolve against the `.env` directory, or the source directory when no `.env` exists.
- Cache metadata now stores the page list so later versioned calls can be fully offline.
- Axure text is extracted from rendered text ranges only and includes each block's source-page bounds; hidden and unrendered annotation content is excluded from requirement prose.
- Sparse canvases larger than 4096 pixels are cropped to visible content when the content occupies less than 65% of the document, and the returned text records the crop mapping.

## Design coordinate fix

Figma imports may place the top-level artboard at an absolute coordinate such as `(11898, -792)` while child frames are already local to the board. v1.8.4 verifies each candidate against the reference canvas, normalizes the artboard and absolute children, retains original `source_bounds`, and records the mapping provenance. Verified snapshots support overview, region inspection, and asset export. Sources that remain unverified allow only an unannotated full overview; region inspection and export return `CoordinateMappingUnverified`.

Existing caches without the stored page list perform one normal request to upgrade their metadata. Later calls use the offline fast path.

## Playwright browser installation fix

Playwright 1.58+ moved Chromium to Chrome for Testing URLs while the installer configured only the legacy Playwright mirror root. The installers now configure both npmmirror roots, retain the legacy layout fallback, and finally fall back to the official Playwright CDN. User-provided mirror overrides remain authoritative.

## Validation

A live three-page Lanhu Axure document was measured through the same requirement path:

| Path | Result |
|---|---:|
| v1.8.3 full cold render | 10.118 s |
| v1.8.4 text-only cold render | 2.428 s |
| v1.8.4 full cold render | 2.565 s |
| v1.8.4 MCP text-only cold call | 5.329 s |
| v1.8.4 MCP text-only warm call | 0.135 s |
| v1.8.4 MCP full warm call | 0.136 s |

The full MCP response still contained three PNG images and extracted text. Ordinary captures measured 1920×1080, 1920×1256, and 1920×1080. A synthetic 20000×20000 Axure canvas verified that hidden text is excluded and the image is cropped below 2000×2500 around visible content.

Regression tests verify exact-version no-network cache hits, one sitemap request per analysis, screenshot-free text-only mode, embedded single-file startup, Figma mixed-origin normalization, safe refusal of unverified exports, hidden Axure text filtering, and sparse-canvas cropping. Package, source installer, browser launch, and MCP stdio checks remain part of release validation.

No real account Cookie is included in the repository, tests, CI configuration, or release artifacts.
