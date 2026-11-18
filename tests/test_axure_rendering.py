"""Rendered Axure evidence excludes hidden text and crops pathological canvases."""

from pathlib import Path

import pytest
from PIL import Image as PillowImage
from playwright.async_api import Error as PlaywrightError

from lanhu_mcp_server import (
    _axure_tiles_for_request,
    _plan_axure_screenshot_tiles,
    _select_axure_screenshot_clip,
    screenshot_page_internal,
)


def test_screenshot_clip_only_targets_large_sparse_canvases():
    issue_metrics = {
        "documentWidth": 19994,
        "documentHeight": 20009,
        "contentBounds": {"x": 50, "y": 100, "width": 1699, "height": 2301},
    }
    assert _select_axure_screenshot_clip(issue_metrics) == {
        "x": 18,
        "y": 68,
        "width": 1763,
        "height": 2365,
    }
    assert _select_axure_screenshot_clip({
        "documentWidth": 1920,
        "documentHeight": 1256,
        "contentBounds": {"x": 0, "y": 0, "width": 1920, "height": 1256},
    }) is None


def test_long_page_plans_overlapping_readable_tiles():
    metrics = {
        "documentWidth": 1920,
        "documentHeight": 3683,
        "contentBounds": {"x": 315.5, "y": 22, "width": 1285, "height": 3661},
    }
    tiles = _plan_axure_screenshot_tiles(metrics)
    assert len(tiles) == 5
    assert {tile["column"] for tile in tiles} == {0}
    assert [tile["row"] for tile in tiles] == [0, 1, 2, 3, 4]
    assert tiles[0]["region"]["y"] == 0
    assert tiles[-1]["region"]["y"] + tiles[-1]["region"]["height"] == 3683
    assert all(tile["region"]["x"] == 0 for tile in tiles)
    assert all(tile["region"]["width"] == 1920 for tile in tiles)
    assert all(tile["region"]["height"] <= 960 for tile in tiles)
    for before, after in zip(tiles, tiles[1:]):
        before_bottom = before["region"]["y"] + before["region"]["height"]
        assert before_bottom > after["region"]["y"]


def test_normal_page_does_not_create_tiles():
    assert _plan_axure_screenshot_tiles({
        "documentWidth": 1920,
        "documentHeight": 1587,
        "contentBounds": {"x": 489, "y": 22, "width": 938, "height": 1565},
    }) == []


def test_tile_request_pagination_returns_only_existing_requested_files(tmp_path):
    plan = []
    for index in range(7):
        file_name = f"tile_{index + 1:03d}.png"
        (tmp_path / file_name).write_bytes(b"png")
        plan.append({"tile_id": f"T{index + 1:03d}", "file_name": file_name})

    selected = _axure_tiles_for_request({"tile_plan": plan}, tmp_path, offset=4, limit=2)
    assert [tile["tile_id"] for tile in selected] == ["T005", "T006"]
    assert all(Path(tile["path"]).exists() for tile in selected)



@pytest.mark.asyncio
async def test_render_filters_hidden_text_and_crops_large_sparse_page(tmp_path):
    resource = tmp_path / "resource"
    output = tmp_path / "output"
    resource.mkdir()
    (resource / "page.html").write_text(
        """<!doctype html><html><head><style>
        html,body { margin:0; width:20000px; height:20000px; }
        #u1 { position:absolute; left:50px; top:100px; width:1700px; height:2300px; background:#fff; }
        #opacity { opacity:0; position:absolute; left:4000px; top:4000px; }
        #display { display:none; }
        </style></head><body>
        <div id="u1">VISIBLE REQUIREMENT</div>
        <div id="opacity">GHOST OPACITY</div>
        <div id="display">GHOST DISPLAY</div>
        </body></html>""",
        encoding="utf-8",
    )
    try:
        result = await screenshot_page_internal(
            str(resource), ["page"], str(output), return_base64=False,
            version_id="issue-126", capture_screenshot=True, include_design_info=False,
            tile_offset=0, tile_limit=2,
        )
    except PlaywrightError as exc:
        if "Executable doesn't exist" in str(exc):
            pytest.skip("Playwright Chromium is not installed in this environment")
        raise

    page = result[0]
    assert page["success"] is True
    assert "VISIBLE REQUIREMENT" in page["page_text"]
    assert "GHOST OPACITY" not in page["page_text"]
    assert "GHOST DISPLAY" not in page["page_text"]
    assert page["page_text_blocks"][0]["bounds"]["x"] == 50
    assert page["screenshot_mode"] == "content_crop"
    assert page["screenshot_region"]["x"] == 18
    assert page["screenshot_region"]["y"] == 68
    assert 1763 <= page["screenshot_region"]["width"] <= 1764
    assert 2364 <= page["screenshot_region"]["height"] <= 2365
    assert page["tile_total"] == 3
    assert len(page["detail_tiles"]) == 2
    with PillowImage.open(Path(page["screenshot_path"])) as image:
        assert image.width <= 1764
        assert image.height <= 2365
    for tile in page["detail_tiles"]:
        with PillowImage.open(Path(tile["path"])) as image:
            assert image.width <= 1764
            assert image.height <= 960


@pytest.mark.asyncio
async def test_detail_tile_failure_keeps_established_full_screenshot(tmp_path, monkeypatch):
    resource = tmp_path / "resource"
    output = tmp_path / "output"
    resource.mkdir()
    (resource / "page.html").write_text(
        """<!doctype html><html><head><style>
        html,body { margin:0; width:1920px; height:3000px; }
        #u1 { position:absolute; inset:0; background:#fff; }
        </style></head><body><div id="u1">LONG REQUIREMENT</div></body></html>""",
        encoding="utf-8",
    )

    async def fail_tile(*args, **kwargs):
        raise RuntimeError("simulated detail tile failure")

    monkeypatch.setattr("lanhu_mcp_server._capture_axure_region", fail_tile)
    try:
        result = await screenshot_page_internal(
            str(resource), ["page"], str(output), return_base64=False,
            version_id="tile-fallback", capture_screenshot=True, include_design_info=False,
            tile_offset=0, tile_limit=2,
        )
    except PlaywrightError as exc:
        if "Executable doesn't exist" in str(exc):
            pytest.skip("Playwright Chromium is not installed")
        raise

    page = result[0]
    assert page["success"] is True
    assert page["screenshot_mode"] == "full_page"
    assert Path(page["screenshot_path"]).exists()
    assert page["tile_total"] >= 2
    assert page["detail_tiles"] == []
    assert [item["tile_id"] for item in page["tile_errors"]] == ["T001", "T002"]
    assert page["tile_next_offset"] == 0
    with PillowImage.open(Path(page["screenshot_path"])) as image:
        assert image.size == (1920, 3000)
