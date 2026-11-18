"""Compact visual evidence for ambiguous Axure requirement references."""

from pathlib import Path

import pytest
from PIL import Image as PillowImage
from playwright.async_api import Error as PlaywrightError

from lanhu_mcp_server import (
    _assign_axure_block_ids,
    _center_axure_focus_region,
    _match_axure_text_blocks,
    capture_axure_focus_regions_internal,
    screenshot_page_internal,
)


def _block(text, x, y):
    return {"text": text, "bounds": {"x": x, "y": y, "width": 120, "height": 20}}


def test_text_anchor_returns_all_exact_duplicates_before_substrings():
    blocks = _assign_axure_block_ids([
        _block("上传图片", 10, 10),
        _block("点击上传图片", 10, 50),
        _block("上传图片", 10, 90),
    ])
    matches = _match_axure_text_blocks(blocks, " 上传 图片 ")
    assert [item["block_id"] for item in matches] == ["B0001", "B0003"]


def test_focus_region_is_centered_and_shifted_inside_page_edges():
    page = {"width": 1920, "height": 4402}
    middle = _center_axure_focus_region(
        {"x": 286.5, "y": 1394, "width": 306, "height": 20}, page, 960, 640
    )
    assert middle == {"x": 0.0, "y": 1084.0, "width": 960.0, "height": 640.0}
    bottom = _center_axure_focus_region(
        {"x": 1800, "y": 4380, "width": 100, "height": 20}, page, 960, 640
    )
    assert bottom == {"x": 960.0, "y": 3762.0, "width": 960.0, "height": 640.0}


@pytest.mark.asyncio
async def test_focus_capture_reads_content_far_from_canvas_origin(tmp_path):
    resource = tmp_path / "resource"
    output = tmp_path / "focus"
    resource.mkdir()
    (resource / "page.html").write_text(
        """<!doctype html><html><head><style>
        html,body { margin:0; width:20000px; height:20000px; background:#eee; }
        #u1 { position:absolute; left:5000px; top:7000px; width:1700px; height:2300px; background:#fff; }
        #target { position:absolute; left:120px; top:180px; color:#fff; background:#d9001b;
                  font:24px sans-serif; padding:12px; }
        </style></head><body><div id="u1"><div id="target">NONZERO TARGET</div></div></body></html>""",
        encoding="utf-8",
    )
    try:
        result = await capture_axure_focus_regions_internal(
            str(resource),
            "page",
            str(output),
            [{
                "label": "tight",
                "kind": "focus_region",
                "anchor": {"x": 5120, "y": 7180, "width": 246, "height": 52},
                "width": 960,
                "height": 640,
            }],
            version_id="focus-nonzero",
        )
    except PlaywrightError as exc:
        if "Executable doesn't exist" in str(exc):
            pytest.skip("Playwright Chromium is not installed")
        raise

    capture = result["captures"][0]
    assert capture["region"]["x"] > 4000
    assert capture["region"]["y"] > 6000
    with PillowImage.open(Path(capture["path"])) as image:
        assert image.size == (960, 640)
        red_pixels = sum(
            1 for red, green, blue in image.convert("RGB").get_flattened_data()
            if red > 180 and green < 80 and blue < 100
        )
        assert red_pixels > 1000


@pytest.mark.asyncio
async def test_focus_capture_can_resolve_a_long_page_tile_id(tmp_path):
    resource = tmp_path / "resource"
    output = tmp_path / "focus"
    resource.mkdir()
    (resource / "page.html").write_text(
        """<!doctype html><html><head><style>
        html,body { margin:0; width:1920px; height:4400px; background:#ddd; }
        #u1 { position:absolute; left:0; top:0; width:1920px; height:4400px; background:#fff; }
        #marker { position:absolute; left:280px; top:1200px; font:24px sans-serif; }
        </style></head><body><div id="u1"><div id="marker">TILE TARGET</div></div></body></html>""",
        encoding="utf-8",
    )
    try:
        result = await capture_axure_focus_regions_internal(
            str(resource), "page", str(output), [], version_id="tile-id", tile_id="T002"
        )
    except PlaywrightError as exc:
        if "Executable doesn't exist" in str(exc):
            pytest.skip("Playwright Chromium is not installed")
        raise

    capture = result["captures"][0]
    assert capture["label"] == "T002"
    assert capture["kind"] == "tile"
    assert capture["region"]["y"] > 0
    with PillowImage.open(Path(capture["path"])) as image:
        assert image.width == 1920
        assert 400 <= image.height <= 960


@pytest.mark.asyncio
async def test_main_sparse_canvas_capture_supports_far_nonzero_origin(tmp_path):
    resource = tmp_path / "resource"
    output = tmp_path / "output"
    resource.mkdir()
    (resource / "page.html").write_text(
        """<!doctype html><html><head><style>
        html,body { margin:0; width:20000px; height:20000px; }
        #u1 { position:absolute; left:5000px; top:7000px; width:1700px; height:2300px; background:#fff; }
        </style></head><body><div id="u1">VISIBLE REQUIREMENT</div></body></html>""",
        encoding="utf-8",
    )
    try:
        result = await screenshot_page_internal(
            str(resource), ["page"], str(output), return_base64=False,
            version_id="far-origin", capture_screenshot=True, include_design_info=False,
            tile_limit=1,
        )
    except PlaywrightError as exc:
        if "Executable doesn't exist" in str(exc):
            pytest.skip("Playwright Chromium is not installed")
        raise

    page = result[0]
    assert page["success"] is True
    assert page["screenshot_mode"] == "content_crop"
    assert page["screenshot_region"]["x"] > 4000
    assert page["screenshot_region"]["y"] > 6000
    assert page["page_text_blocks"][0]["block_id"] == "B0001"
    with PillowImage.open(Path(page["screenshot_path"])) as image:
        assert 1700 <= image.width <= 1765
        assert 2300 <= image.height <= 2365
