# moon-clib

A MoonBit CLI tool for downloading, building, caching, and installing C libraries into `$MOON_HOME`.

`moon-clib` reads `moon.lib.json` from your project, resolves the exact C library versions you need via one or more package repositories, builds them (or reuses cached builds), and installs them under `$MOON_HOME` (`bin/`, `lib/`, `include/`, `share/`).

For the full design and manifest schema details, see `DESIGN.md`.

## Quick Start

1. Configure a package repository.

```bash
moon-clib repo add /path/to/moon-clib-packages
# or
moon-clib repo add https://example.com/moon-clib-packages
```

2. Create `moon.lib.json` in your project root.

```json
{
  "dependencies": {
    "zlib": "1.3.1",
    "openssl": "3.2.0"
  }
}
```

3. Install libraries.

```bash
moon-clib
```

## Commands

```text
moon-clib                      # Install all libraries from moon.lib.json
moon-clib --force              # Reinstall even if already installed
moon-clib list                 # List installed libraries
moon-clib info <name>          # Show info about a library
moon-clib remove <name>        # Remove an installed library

moon-clib repo list            # List configured repositories
moon-clib repo add <url>       # Add a repository (URL or local path)
moon-clib repo remove <url>    # Remove a repository
moon-clib repo update          # Update repository indexes (placeholder)

moon-clib cache list           # List cached packages
moon-clib cache clean          # Remove all cached packages
```

## Project Configuration

### `moon.lib.json`

Required fields:

- `dependencies`: Map of library name to exact version string.

Example:

```json
{
  "dependencies": {
    "c-ares": "1.24.0",
    "zlib": "1.3.1"
  }
}
```

### Global config (`config.json`)

`moon-clib` uses a global config file for repositories:

- macOS and Linux default: `~/.config/moon-clib/config.json`
- Linux honors `XDG_CONFIG_HOME`

Example:

```json
{
  "repositories": [
    "https://example.com/moon-clib-packages",
    "/home/user/moon-clib-packages"
  ]
}
```

If no repositories are configured, `moon-clib` cannot resolve packages.

## Package Repositories

A package repository can be a local directory or a remote HTTP host. Layout is:

```text
{repo}/
  {name}/
    {version}/
      manifest.json
      ... optional patches/files ...
```

`manifest.json` fully describes how to fetch, build, and install a library. See `DESIGN.md` for the complete schema and examples.

## Cache and Install Locations

- Install prefix: `$MOON_HOME` (default `~/.moon`)
- Install manifest: `$MOON_HOME/lib/moon-clib.json`
- Cache directory (macOS): `~/Library/Caches/moon-clib`
- Cache directory (Linux): `$XDG_CACHE_HOME/moon-clib` or `~/.cache/moon-clib`
- Cache override: `MOON_CLIB_CACHE`

Cached packages are stored as tarballs and reused to avoid rebuilding.

## Environment Variables

- `MOON_HOME`: Install prefix (default `~/.moon`)
- `MOON_CLIB_CACHE`: Override cache directory
- `XDG_CONFIG_HOME`: Override config base directory (Linux)
- `XDG_CACHE_HOME`: Override cache base directory (Linux)

## Development

This is a MoonBit project. Typical workflows:

```bash
moon build
moon test
```

## License

Apache-2.0
