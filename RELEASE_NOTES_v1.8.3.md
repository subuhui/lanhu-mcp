# v1.8.3 - Windows installation release gate

Windows is now a first-class release target rather than a source-only assumption.

## Added

Every CI and tagged release runs a clean Windows installation job on GitHub's `windows-latest` runner with Python 3.13. The job:

- invokes `easy-install.bat` by absolute path from a different working directory;
- creates a new virtual environment and installs the project through the batch installer;
- runs `pip check`, `lanhu-mcp --version`, and `lanhu-mcp --help`;
- downloads Chromium with Playwright and performs a real headless page render;
- starts `lanhu-mcp.exe --transport stdio`, completes the MCP initialize handshake, and verifies all 16 tools;
- confirms the caller directory was not polluted by relative installer paths.

## Fixed during Windows validation

The first real Windows gate exposed a `cmd.exe` parsing bug in the old inline Python version comparison: Python 3.13.15 was incorrectly reported as older than 3.10. Version detection now reads numeric major/minor fields and compares them with batch-native `LSS`/`EQU` operators.

## Installer behavior

Normal Windows users still get the guided interactive flow. `LANHU_INSTALL_NONINTERACTIVE=1` and `LANHU_SKIP_BROWSER_INSTALL=1` are audit/automation controls; the release gate separately downloads and launches Chromium so browser support remains verified.
