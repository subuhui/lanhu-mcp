# v1.8.2 - Resilient domestic installation

This patch follows a fresh public-tag installation audit of v1.8.1. During the audit, Tsinghua PyPI returned HTTP 403 to a current pip client even though ordinary browser requests still succeeded. A clean Python 3.14 environment therefore could not obtain the isolated `setuptools` build dependency.

## Fixed

- Prefer Aliyun PyPI for domestic source installations.
- Automatically retry Tsinghua PyPI and then official PyPI when a default package source is unavailable.
- Preserve an explicitly supplied `PIP_INDEX_URL` without silently changing it.
- Run shell and Windows installers from their own checkout directory, so invoking a script by absolute path cannot create or reuse `venv`, `.env`, `data`, or `logs` in the caller's directory.
- Keep Chromium downloads on the npmmirror Playwright mirror by default.

## Validation

The public `v1.8.2` source flow is validated from a fresh checkout with a new virtual environment, empty pip cache, and empty Playwright browser directory. Validation covers package installation through the domestic default, Chromium installation, a real browser launch, CLI version/help, dependency integrity, and an MCP stdio handshake exposing all tools.
