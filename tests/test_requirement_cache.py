"""Regression coverage for Axure cache hits and single-pass page analysis."""

import hashlib
import json

import pytest
from fastmcp import Client, FastMCP

import lanhu_mcp_server as server


URL = (
    "https://lanhuapp.com/web/#/item/project/product?tid=team&pid=project"
    "&docId=document&versionId=version-1"
)


@pytest.mark.asyncio
async def test_exact_version_resource_cache_never_requires_network(tmp_path):
    output = tmp_path / "axure"
    output.mkdir()
    for directory in ("data", "resources", "files", "images"):
        (output / directory).mkdir()
    (output / "page.html").write_text("<html></html>", encoding="utf-8")
    pages = [{
        "index": 1, "name": "页面", "filename": "page.html", "id": "page-id",
        "type": "Wireframe", "level": 0, "folder": "根目录", "path": "页面",
        "has_children": False,
    }]
    (output / server.LanhuExtractor.CACHE_META_FILE).write_text(json.dumps({
        "version_id": "version-1", "document_name": "需求", "page_list": pages,
        "files": {"page.html": hashlib.sha256((output / "page.html").read_bytes()).hexdigest()},
    }), encoding="utf-8")

    extractor = server.LanhuExtractor()
    async def unexpected_network(*args, **kwargs):
        raise AssertionError("exact-version cache hit must not access Lanhu")
    extractor.get_document_info = unexpected_network
    try:
        result = await extractor.download_resources(URL, str(output))
    finally:
        await extractor.close()

    assert result["status"] == "cached"
    assert result["reason"] == "exact_version_cache"
    assert result["pages"] == pages


@pytest.mark.asyncio
@pytest.mark.parametrize("mode, expected_capture", [("text_only", False), ("full", True)])
async def test_analyze_reuses_download_sitemap_and_selects_render_cost(
    tmp_path, monkeypatch, mode, expected_capture
):
    calls = []

    class FakeExtractor:
        def parse_url(self, url):
            return {"doc_id": "document"}

        async def download_resources(self, url, output_dir):
            return {
                "status": "cached", "version_id": "version-1",
                "pages": [{"name": "页面", "filename": "page.html"}],
            }

        async def get_pages_list(self, url):
            raise AssertionError("analysis must not request the sitemap twice")

        async def close(self):
            pass

    async def fake_render(resource_dir, page_names, output_dir, **options):
        calls.append(options)
        return [{
            "page_name": "page", "success": True, "page_text": "需求正文",
            "page_design_info": {"textColors": []} if expected_capture else None,
            "page_annotations": {}, "from_cache": True,
            **({"screenshot_path": str(tmp_path / "page.png")} if expected_capture else {}),
        }]

    if expected_capture:
        (tmp_path / "page.png").write_bytes(
            b"\x89PNG\r\n\x1a\n"  # Image is constructed only after the tool returns; avoid reading it below.
        )

    monkeypatch.setattr(server, "DATA_DIR", tmp_path)
    monkeypatch.setattr(server, "LanhuExtractor", FakeExtractor)
    monkeypatch.setattr(server, "screenshot_page_internal", fake_render)
    # Keep this test focused on orchestration; FastMCP image decoding is covered elsewhere.
    monkeypatch.setattr(server, "Image", lambda **kwargs: "image")

    probe = FastMCP("requirement-orchestration-test")
    probe.tool()(server.lanhu_get_ai_analyze_page_result)
    async with Client(probe) as client:
        result = await client.call_tool("lanhu_get_ai_analyze_page_result", {
            "url": URL, "page_names": "all", "mode": mode, "analysis_mode": "developer",
        })

    assert not result.is_error
    assert calls == [{
        "return_base64": False,
        "version_id": "version-1",
        "capture_screenshot": expected_capture,
        "include_design_info": expected_capture,
        "tile_offset": 0,
        "tile_limit": server.AXURE_DEFAULT_TILE_LIMIT,
    }]
