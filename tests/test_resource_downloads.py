"""Resource cache boundaries and status contracts."""

import json

import httpx
import pytest

from lanhu_mcp_server import LanhuExtractor


class FakeResponse:
    def __init__(self, *, payload=None, content=b"body"):
        self._payload = payload
        self.content = content
        self.text = content.decode("utf-8")

    def raise_for_status(self):
        return None

    def json(self):
        return self._payload


class ResourceClient:
    def __init__(self, project_mapping, *, fail_suffix=None):
        self.project_mapping = project_mapping
        self.fail_suffix = fail_suffix

    async def get(self, url, **kwargs):
        if self.fail_suffix and url.endswith(self.fail_suffix):
            raise httpx.ConnectError("synthetic download failure")
        if url == "https://example.test/project.json":
            return FakeResponse(payload=self.project_mapping, content=json.dumps(self.project_mapping).encode())
        if url.endswith("page-mapping"):
            return FakeResponse(payload={"images": {"images/icon.png": {"sign_md5": "asset"}}})
        return FakeResponse(content=b"resource")


def extractor_with(project_mapping, *, fail_suffix=None, version="v1"):
    extractor = object.__new__(LanhuExtractor)
    extractor.client = ResourceClient(project_mapping, fail_suffix=fail_suffix)

    async def get_document_info(*args, **kwargs):
        return {"name": "Document", "versions": [{"id": version, "json_url": "https://example.test/project.json"}]}

    extractor.get_document_info = get_document_info
    return extractor


@pytest.mark.asyncio
async def test_remote_resource_path_cannot_escape_output_directory(tmp_path):
    extractor = extractor_with({})
    mapping = {"styles": {"../../escape.css": {"sign_md5": "asset"}}}

    with pytest.raises(ValueError, match="escapes"):
        await extractor._download_page_resources(mapping, tmp_path / "cache")
    assert not (tmp_path / "escape.css").exists()


@pytest.mark.asyncio
async def test_dependency_failure_does_not_commit_successful_cache(tmp_path):
    project_mapping = {
        "pages": {"index.html": {"html": {"sign_md5": "page-html"}, "mapping_md5": "page-mapping"}}
    }
    extractor = extractor_with(project_mapping, fail_suffix="asset")
    output = tmp_path / "cache"

    with pytest.raises(httpx.ConnectError):
        await extractor.download_resources("?pid=project&docId=document", str(output))
    assert not (output / LanhuExtractor.CACHE_META_FILE).exists()


@pytest.mark.asyncio
async def test_download_status_distinguishes_first_download_and_version_update(tmp_path):
    output = tmp_path / "cache"
    output.mkdir()
    first = extractor_with({"pages": {}}, version="v1")
    initial = await first.download_resources("?pid=project&docId=document", str(output))
    assert initial["status"] == "downloaded"
    assert initial["reason"] == "first_download"

    updated = extractor_with({"pages": {}}, version="v2")
    changed = await updated.download_resources("?pid=project&docId=document", str(output))
    assert changed["status"] == "updated"
    assert changed["reason"] == "version_changed"


@pytest.mark.asyncio
async def test_corrupted_cached_file_forces_a_verified_redownload(tmp_path):
    project_mapping = {"pages": {"index.html": {"html": {"sign_md5": "page-html"}}}}
    output = tmp_path / "cache"
    initial = extractor_with(project_mapping)
    await initial.download_resources("?pid=project&docId=document", str(output))
    (output / "index.html").write_bytes(b"corrupted")

    refreshed = extractor_with(project_mapping)
    result = await refreshed.download_resources("?pid=project&docId=document", str(output))
    assert result["status"] == "updated"
    assert result["reason"] == "files_invalid"
    assert (output / "index.html").read_bytes() == b"resource"
