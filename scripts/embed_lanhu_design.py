#!/usr/bin/env python3
"""Embed lanhu_design into lanhu_mcp_server.py for true single-file deployment."""

from __future__ import annotations

import argparse
import base64
import hashlib
import io
import textwrap
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "lanhu_mcp_server.py"
PACKAGE = ROOT / "lanhu_design"
BEGIN = "# BEGIN EMBEDDED LANHU_DESIGN (generated; run scripts/embed_lanhu_design.py)"
END = "# END EMBEDDED LANHU_DESIGN"
INSERT_AFTER = "from typing import Annotated, Optional, Union, List, Any\n"


def package_zip() -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(PACKAGE.glob("*.py")):
            info = zipfile.ZipInfo(f"lanhu_design/{path.name}", (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes())
    return buffer.getvalue()


def generated_block() -> str:
    payload = package_zip()
    digest = hashlib.sha256(payload).hexdigest()
    encoded = "\n".join(textwrap.wrap(base64.b64encode(payload).decode("ascii"), 100))
    return f'''{BEGIN}
_EMBEDDED_LANHU_DESIGN_SHA256 = "{digest}"
_EMBEDDED_LANHU_DESIGN_ZIP = """{encoded}"""


def _enable_embedded_lanhu_design() -> None:
    import importlib.util
    import tempfile

    force = os.getenv("LANHU_FORCE_EMBEDDED_DESIGN") == "1"
    if not force and importlib.util.find_spec("lanhu_design") is not None:
        return
    payload = base64.b64decode(_EMBEDDED_LANHU_DESIGN_ZIP)
    if hashlib.sha256(payload).hexdigest() != _EMBEDDED_LANHU_DESIGN_SHA256:
        raise RuntimeError("Embedded lanhu_design payload failed integrity verification")
    user_key = str(getattr(os, "getuid", lambda: Path.home())())
    cache_dir = Path(tempfile.gettempdir()) / f"lanhu-mcp-embedded-{{hashlib.sha256(user_key.encode()).hexdigest()[:12]}}"
    cache_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    archive = cache_dir / f"lanhu-design-{{_EMBEDDED_LANHU_DESIGN_SHA256[:16]}}.zip"
    if not archive.is_file() or hashlib.sha256(archive.read_bytes()).hexdigest() != _EMBEDDED_LANHU_DESIGN_SHA256:
        with tempfile.NamedTemporaryFile(dir=cache_dir, prefix=".lanhu-design-", delete=False) as handle:
            handle.write(payload)
            temporary = Path(handle.name)
        try:
            temporary.chmod(0o600)
            temporary.replace(archive)
        finally:
            temporary.unlink(missing_ok=True)
    sys.path.insert(0, str(archive))


_enable_embedded_lanhu_design()
{END}
'''


def render(source: str) -> str:
    block = generated_block()
    if BEGIN in source:
        start = source.index(BEGIN)
        end = source.index(END, start) + len(END)
        while end < len(source) and source[end] == "\n":
            end += 1
        return source[:start] + block + "\n" + source[end:]
    if INSERT_AFTER not in source:
        raise SystemExit("server import marker not found")
    return source.replace(INSERT_AFTER, INSERT_AFTER + "\n" + block + "\n", 1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    source = SERVER.read_text(encoding="utf-8")
    updated = render(source)
    if args.check:
        if source != updated:
            raise SystemExit("embedded lanhu_design is stale; run scripts/embed_lanhu_design.py")
        print("embedded lanhu_design is current")
        return
    SERVER.write_text(updated, encoding="utf-8")
    print(f"embedded {len(package_zip())} bytes into {SERVER.name}")


if __name__ == "__main__":
    main()
