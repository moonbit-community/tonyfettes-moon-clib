# moon-clib Design

A MoonBit CLI tool for downloading, building, and installing C libraries to `$MOON_HOME`.

## Overview

`moon-clib` (invoked as `moon-clib` or `moon clib`) reads `moon.lib.json` from
the current directory to determine which C libraries are needed, fetches build
manifests from package repositories, then builds and installs the libraries to
`$MOON_HOME` (organized like Unix root: `bin/`, `lib/`, `include/`, `share/`).

## Architecture

```
┌─────────────────┐     ┌─────────────────────┐     ┌─────────────┐
│  moon.lib.json  │────▶│  Package Repository │────▶│  $MOON_HOME │
│  (in project)   │     │  (build manifests)  │     │  (install)  │
│                 │     │                     │     │             │
│  dependencies:  │     │  c-ares/1.24.0.json │     │  lib/       │
│    c-ares:1.24.0│     │  zlib/1.3.1.json    │     │  include/   │
│    zlib:1.3.1   │     │  ...                │     │  bin/       │
└─────────────────┘     └─────────────────────┘     └─────────────┘
```

**Separation of concerns:**

- **moon.lib.json** (per-project): Declares *what* libraries are needed
- **Package repository**: Defines *how* to build each library
- **Cache**: Stores built packages for fast reinstall

## moon.lib.json (Project Dependencies)

Each project has a `moon.lib.json` that lists required C libraries with exact versions:

```json
{
  "dependencies": {
    "c-ares": "1.24.0",
    "openssl": "3.2.0",
    "zlib": "1.3.1"
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `dependencies` | Yes | Map of library name to exact version |

That's it. No build instructions here—those come from the package repository.

## Package Repository

Build manifests are stored in a separate repository, organized by library name and version:

```
moon-clib-pkg/
├── c-ares/
│   ├── 1.24.0/
│   │   └── manifest.json
│   └── 1.25.0/
│       ├── manifest.json
│       └── fix-build.patch       # Local patches stored with manifest
├── openssl/
│   └── 3.2.0/
│       ├── manifest.json
│       ├── fix-arm64.patch
│       └── fix-macos.patch
└── zlib/
    └── 1.3.1/
        └── manifest.json
```

Each package version is a directory containing:

- `manifest.json` - The build specification (required)
- Additional files (patches, scripts, etc.) - Referenced by the manifest

### Repository Configuration

Repositories can be local paths or remote URLs:

```
~/.config/moon-clib/config.json
```

```json
{
  "repositories": [
    "https://github.com/anthropics/moon-clib-packages",
    "/home/user/my-custom-packages"
  ]
}
```

Repositories are searched in order. The first matching manifest wins.

**To customize a package:** Fork the repository, modify the manifest, add your fork as a repository.

## Package Manifest Schema

Each `{name}/{version}/manifest.json` file contains the full build specification:

```json
{
  "description": "A C library for asynchronous DNS requests",
  "author": "Daniel Stenberg <daniel@haxx.se>",
  "license": "MIT",
  "homepage": "https://c-ares.org",

  "source": [ /* array of sources */ ],

  "dependencies": {
    "zlib": "1.3.1"
  },

  "build": [ /* array of build steps */ ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `description` | No | Brief description |
| `author` | No | Author name and email |
| `license` | No | SPDX license identifier |
| `homepage` | No | Project homepage URL |
| `source` | Yes | Array of source specifications |
| `dependencies` | No | Map of dependency name to exact version |
| `build` | Yes | Array of build steps |

### Source Specification

Each source in the `source` array has a `type` field and type-specific fields:

#### Tarball Source

```json
{
  "type": "tarball",
  "url": "https://example.org/lib-1.0.tar.gz",
  "sha256": "abc123...",
  "strip_components": 1,
  "dest": "lib"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Must be `"tarball"` |
| `url` | Yes | URL to download |
| `sha256` | No | SHA256 checksum for integrity verification |
| `strip_components` | No | Equivalent to `tar --strip-components=N` (default: 0) |
| `dest` | No | Destination directory relative to `${SRCDIR}` |

#### Git Source

```json
{
  "type": "git",
  "url": "https://github.com/org/repo.git",
  "ref": "v1.24.0",
  "shallow": true,
  "dest": "repo"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Must be `"git"` |
| `url` | Yes | Git repository URL |
| `ref` | Yes | Tag, branch, or commit SHA |
| `shallow` | No | Use shallow clone (default: true) |
| `dest` | No | Destination directory relative to `${SRCDIR}` |

#### File Source

For remote files:

```json
{
  "type": "file",
  "url": "https://example.org/fix.patch",
  "sha256": "...",
  "dest": "patches/fix.patch"
}
```

For local files (in the package directory):

```json
{
  "type": "file",
  "path": "fix-build.patch",
  "dest": "patches/fix-build.patch"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Must be `"file"` |
| `url` | No | URL to download (use either `url` or `path`) |
| `path` | No | Path relative to package directory (use either `url` or `path`) |
| `sha256` | No | SHA256 checksum for integrity verification (for `url` only) |
| `dest` | No | Destination path relative to `${SRCDIR}` |

Using `path` allows patches and other files to be stored alongside the manifest in the package repository, reducing external dependencies.

#### Local Source

For referencing local directories on the user's machine (development use):

```json
{
  "type": "local",
  "path": "./vendor/lib",
  "dest": "vendor"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Must be `"local"` |
| `path` | Yes | Local filesystem path (absolute or relative to moon.lib.json) |
| `dest` | No | Destination directory relative to `${SRCDIR}` |

#### Default `dest` Values

If `dest` is omitted, it defaults to a name derived from the URL:

- `https://example.org/lib-1.0.tar.gz` → `lib-1.0`
- `https://github.com/org/repo.git` → `repo`
- `https://example.org/fix.patch` → `fix.patch`

### Build Step Specification

Each step in the `build` array is an object:

```json
{
  "run": ["cmd", "arg1", "arg2"],
  "when": { "os": "linux", "arch": "x86_64" },
  "env": { "CC": "clang" },
  "cwd": "lib"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `run` | Yes | Command as array of strings (avoids shell quoting issues) |
| `when` | No | Condition for running this step |
| `env` | No | Step-specific environment variables (values support `${VAR}` expansion) |
| `cwd` | No | Working directory relative to `${SRCDIR}` |

#### Condition Matching

The `when` field controls when a step runs:

```json
{
  "when": {
    "os": "linux",
    "arch": "x86_64"
  }
}
```

- If `when` is omitted, step always runs
- If `when.os` is specified, step runs only on that OS (`linux`, `darwin`, `windows`)
- If `when.arch` is specified, step runs only on that architecture (`x86_64`, `aarch64`, etc.)
- If both are specified, both must match

### Variable Expansion

Only `${VAR}` syntax is supported. Variables are expanded in `run` array elements and in `env` values (keys are not expanded).

| Variable | Description |
|----------|-------------|
| `${PREFIX}` | Installation prefix (`$MOON_HOME`) |
| `${DESTDIR}` | Staging directory for installation (temp directory managed by moon-clib) |
| `${JOBS}` | Parallel job count |
| `${SRCDIR}` | Source directory (in cache: `~/.cache/moon-clib/src/{name}-{version}/`) containing all downloaded sources |
| `${OS}` | Current OS (`darwin`, `linux`, `windows`) |
| `${ARCH}` | Current architecture (`x86_64`, `aarch64`, etc.) |

### Command Execution

Each build step runs with:

- **cwd** = `${SRCDIR}/{cwd}` (or just `${SRCDIR}` if `cwd` is omitted)
- **env** = inherited environment + step-specific `env` + variables above

Example env usage with expansion:

```json
{
  "run": ["./configure", "--prefix=${PREFIX}"],
  "env": {
    "CPPFLAGS": "-I${PREFIX}/include",
    "LDFLAGS": "-L${PREFIX}/lib",
    "PKG_CONFIG_PATH": "${PREFIX}/lib/pkgconfig"
  }
}
```

### DESTDIR Installation Pattern

Build steps should install to `${DESTDIR}${PREFIX}/...` rather than directly to `${PREFIX}`. This allows moon-clib to:

1. Capture the list of installed files by scanning `${DESTDIR}`
2. Copy files from `${DESTDIR}` to `${PREFIX}`
3. Record the file list in the manifest for future uninstallation

**For build systems with DESTDIR support:**

```json
{"run": ["make", "install", "DESTDIR=${DESTDIR}"]}
{"run": ["cmake", "--install", "build", "--prefix", "${DESTDIR}${PREFIX}"]}
{"run": ["meson", "install", "-C", "build", "--destdir", "${DESTDIR}"]}
```

**For build systems without DESTDIR support**, use manual installation:

```json
{"run": ["install", "-Dm755", "build/libfoo.so", "${DESTDIR}${PREFIX}/lib/libfoo.so"]}
{"run": ["install", "-Dm644", "include/foo.h", "${DESTDIR}${PREFIX}/include/foo.h"]}
```

Using `${SRCDIR}` provides better readability than relative paths with multiple `..`:

## Package Manifest Examples

These examples show the contents of package manifest files in the repository.

### c-ares/1.24.0/manifest.json (CMake library)

```json
{
  "description": "A C library for asynchronous DNS requests",
  "author": "Daniel Stenberg <daniel@haxx.se>",
  "license": "MIT",
  "homepage": "https://c-ares.org",

  "source": [
      {
        "type": "tarball",
        "url": "https://c-ares.org/download/c-ares-1.24.0.tar.gz",
        "sha256": "0a72be66959955c43e2af2fbd03418e82a2bd5464604e3e0a6c0dc7d1f1fdc5f",
        "strip_components": 1,
        "dest": "c-ares"
      }
    ],

    "build": [
      {
        "run": ["cmake", "-B", "build",
                "-DCMAKE_INSTALL_PREFIX=${PREFIX}",
                "-DCMAKE_BUILD_TYPE=Release",
                "-DCARES_STATIC=OFF",
                "-DCARES_SHARED=ON",
                "-DCARES_BUILD_TESTS=OFF"],
        "cwd": "c-ares"
      },
      {
        "run": ["cmake", "--build", "build", "-j${JOBS}"],
        "cwd": "c-ares"
      },
      {
        "run": ["cmake", "--install", "build", "--prefix", "${DESTDIR}${PREFIX}"],
        "cwd": "c-ares"
      }
    ]
}
```

### openssl/3.2.0/manifest.json (platform-specific build)

```json
{
  "license": "Apache-2.0",

  "source": [
      {
        "type": "tarball",
        "url": "https://www.openssl.org/source/openssl-3.2.0.tar.gz",
        "sha256": "...",
        "strip_components": 1,
        "dest": "openssl"
      }
    ],

    "dependencies": {
      "zlib": "1.3.1"
    },

    "build": [
      {
        "when": { "os": "linux", "arch": "x86_64" },
        "run": ["./Configure", "linux-x86_64", "--prefix=${PREFIX}", "shared", "zlib"],
        "cwd": "openssl"
      },
      {
        "when": { "os": "linux", "arch": "aarch64" },
        "run": ["./Configure", "linux-aarch64", "--prefix=${PREFIX}", "shared", "zlib"],
        "cwd": "openssl"
      },
      {
        "when": { "os": "darwin", "arch": "x86_64" },
        "run": ["./Configure", "darwin64-x86_64-cc", "--prefix=${PREFIX}", "shared", "zlib"],
        "cwd": "openssl"
      },
      {
        "when": { "os": "darwin", "arch": "aarch64" },
        "run": ["./Configure", "darwin64-arm64-cc", "--prefix=${PREFIX}", "shared", "zlib"],
        "cwd": "openssl"
      },
      {
        "run": ["make", "-j${JOBS}"],
        "cwd": "openssl"
      },
      {
        "run": ["make", "install_sw", "install_ssldirs", "DESTDIR=${DESTDIR}"],
        "cwd": "openssl"
      }
    ]
}
```

### example-lib/1.0.0/manifest.json (with local patch file)

The package directory contains:

```
example-lib/1.0.0/
├── manifest.json
└── fix-build.patch      # Patch stored alongside manifest
```

manifest.json:

```json
{
  "source": [
      {
        "type": "tarball",
        "url": "https://example.org/lib-1.0.0.tar.gz",
        "sha256": "...",
        "strip_components": 1,
        "dest": "lib"
      },
      {
        "type": "file",
        "path": "fix-build.patch",
        "dest": "patches/fix-build.patch"
      }
    ],

    "build": [
      {
        "run": ["patch", "-p1", "-i", "${SRCDIR}/patches/fix-build.patch"],
        "cwd": "lib"
      },
      {
        "run": ["./configure", "--prefix=${PREFIX}"],
        "cwd": "lib"
      },
      {
        "run": ["make", "-j${JOBS}"],
        "cwd": "lib"
      },
      {
        "run": ["make", "install", "DESTDIR=${DESTDIR}"],
        "cwd": "lib"
      }
    ]
}
```

The patch file is stored in the package repository alongside the manifest, so it's downloaded together—no separate hosting needed.

### simple-lib/1.0.0/manifest.json (manual installation, no DESTDIR support)

```json
{
  "source": [
      {
        "type": "tarball",
        "url": "https://example.org/simple-1.0.0.tar.gz",
        "sha256": "...",
        "strip_components": 1,
        "dest": "simple"
      }
    ],

    "build": [
      {
        "run": ["make", "-j${JOBS}"],
        "cwd": "simple"
      },
      {
        "run": ["install", "-Dm755", "libsimple.so", "${DESTDIR}${PREFIX}/lib/libsimple.so"],
        "cwd": "simple"
      },
      {
        "run": ["install", "-Dm644", "simple.h", "${DESTDIR}${PREFIX}/include/simple.h"],
        "cwd": "simple"
      }
    ]
}
```

## CLI Interface

### Commands

```
moon-clib                      # Install all libraries from moon.lib.json
moon-clib --force              # Reinstall even if already installed
moon-clib list                 # List installed libraries
moon-clib info <name>          # Show info about a library
moon-clib remove <name>        # Remove an installed library

moon-clib repo list            # List configured repositories
moon-clib repo add <url>       # Add a repository (URL or local path)
moon-clib repo remove <url>    # Remove a repository
moon-clib repo update          # Update repository index/cache

moon-clib cache list           # List cached packages
moon-clib cache clean          # Remove all cached packages
```

### Behavior

1. Reads `moon.lib.json` from current directory
2. For each dependency, fetches package manifest from repositories
3. Resolves transitive dependencies (topological sort)
4. For each library (in dependency order):
   - Checks install manifest for existing installation
   - Skips if version matches (unless `--force`)
   - Checks cache for `{name}-{version}-{os}-{arch}.tar.gz`
   - If cached and checksum valid:
     - Extracts package to `${PREFIX}`
     - Updates install manifest with file list
   - If not cached (or checksum invalid):
     - Creates `${SRCDIR}` directory (in cache: `~/.cache/moon-clib/src/{name}-{version}/`)
     - Creates temporary `${DESTDIR}` directory
     - Downloads all sources to their `dest` paths within `${SRCDIR}`
     - Executes build steps with condition matching
     - Scans `${DESTDIR}` to discover installed files
     - Creates tarball from `${DESTDIR}`, saves to cache with `.sha256`
     - Copies files from `${DESTDIR}` to `${PREFIX}`
     - Updates install manifest with file list
     - Cleans up `${DESTDIR}`

## Package Cache

Built packages are cached outside `$MOON_HOME` so they survive toolchain reinstalls.

### Cache Location

| Platform | Default Location |
|----------|------------------|
| Linux | `$XDG_CACHE_HOME/moon-clib/` or `~/.cache/moon-clib/` |
| macOS | `~/Library/Caches/moon-clib/` |
| Override | `$MOON_CLIB_CACHE` environment variable |

### Cache Structure

```
~/.cache/moon-clib/
├── pkg/                              # Built packages
│   ├── c-ares-1.24.0-linux-x86_64.tar.gz
│   ├── c-ares-1.24.0-linux-x86_64.tar.gz.sha256
│   ├── openssl-3.2.0-linux-x86_64.tar.gz
│   ├── openssl-3.2.0-linux-x86_64.tar.gz.sha256
│   └── ...
└── src/                                   # Source directories (${SRCDIR})
    ├── c-ares-1.24.0/
    │   └── c-ares/                        # Extracted tarball
    ├── openssl-3.2.0/
    │   └── openssl/
    └── ...
```

**pkg/**: Built package tarballs

- **Filename**: `{name}-{version}-{os}-{arch}.tar.gz`
- **Contents**: Files relative to `${PREFIX}` (same as what would be installed)
- **Checksum**: `.sha256` file for integrity verification

**src/**: Source directories used during build

- Created when building from source
- Can be cleaned with `moon-clib cache clean`

## Manifest

Installed libraries are tracked in `$MOON_HOME/lib/moon-clib.json`:

```json
{
  "installed": {
    "c-ares": {
      "version": "1.24.0",
      "installed_at": "2024-01-15T10:30:00Z",
      "files": ["lib/libcares.so", "lib/libcares.so.2", "include/ares.h"]
    }
  }
}
```

### How File Tracking Works

**When building from source:**

1. moon-clib creates a temporary `${DESTDIR}` directory
2. Build steps install files to `${DESTDIR}${PREFIX}/...`
3. After build completes, moon-clib scans `${DESTDIR}` to discover installed files
4. A tarball is created from `${DESTDIR}` and saved to cache with checksum
5. Files are copied from `${DESTDIR}` to `${PREFIX}` (the real `$MOON_HOME`)
6. The file list is recorded in the manifest

**When installing from cache:**

1. moon-clib verifies the `.sha256` checksum
2. Extracts the tarball directly to `${PREFIX}`
3. The file list is derived from the tarball contents and recorded in manifest

This enables:

- **Clean uninstall**: `moon-clib remove <name>` can delete exactly the files that were installed
- **Conflict detection**: Warn if a new library would overwrite files from another library
- **Fast reinstall**: After toolchain upgrade, cached packages are extracted without rebuilding
