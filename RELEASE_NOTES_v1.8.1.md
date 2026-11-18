# v1.8.1 - Reliable source installation for domestic users

This patch fixes the non-Docker installation path. The previous `easy-install`
script accepted macOS system Python 3.9 and then failed during FastMCP dependency
resolution. It also installed only `requirements.txt`, leaving the package CLI
uninstalled.

## Fixed

- Require and verify Python 3.10 or newer before creating `venv`.
- Install the project with `pip install -e .`, then run `pip check`.
- Start HTTP and stdio modes through the installed `lanhu-mcp` entry point.
- Do not abort when `clear` is unavailable in an AI/IDE subprocess.
- Avoid a nonessential pip self-upgrade before project installation.
- Use a 60-second package index timeout with five retries and a clear network
  diagnostic when dependency installation still fails.
- Detect invalid or outdated existing `venv` directories and report the exact
  recovery action.

## Domestic download defaults

The source installer scripts now default to:

- Tsinghua PyPI: `https://pypi.tuna.tsinghua.edu.cn/simple`
- npmmirror Playwright binaries: `https://cdn.npmmirror.com/binaries/playwright`

Set `PIP_INDEX_URL` or `PLAYWRIGHT_DOWNLOAD_HOST` before running the installer to
override either source.

## Validation

A fresh public-style source checkout was tested with Python 3.10, an empty pip
cache, no prior virtual environment, and an empty Playwright browser directory.
The installer downloaded and installed all dependencies, Chromium, FFmpeg, and
the Chromium headless shell from the domestic defaults and exited successfully.
The resulting environment then passed:

- `lanhu-mcp --version` and `lanhu-mcp --help`
- a real headless Chromium launch and page render
- an MCP stdio handshake exposing all 16 tools
- an authorized read-only Lanhu design-list call through the installed stdio server

The macOS/Linux flow was executed end to end. Windows batch changes are covered by
source regression checks and the package's cross-platform entry point, but were
not executed on a local Windows host during this validation.
