# moon-clib Design

A MoonBit CLI tool for downloading, building, and installing C libraries to `$MOON_HOME`.

## Overview

`moon-clib` (invoked as `moon-clib` or `moon clib`) reads `moon.lib.json` from the current directory, downloads C library sources to `$MOON_HOME/src/`, builds them, and installs to `$MOON_HOME` (organized like Unix root: `bin/`, `lib/`, `include/`, `share/`).

## moon.lib.json Schema

### Top-Level Structure

The file is a JSON object where each key is a library name:

```json
{
  "c-ares": { /* library specification */ },
  "zlib": { /* library specification */ }
}
```

### Library Specification

```json
{
  "library-name": {
    "version": "1.24.0",
    "description": "...",
    "author": "Name <email>",
    "license": "MIT",
    "homepage": "https://...",

    "source": [ /* array of sources */ ],

    "dependencies": {
      "zlib": ">=1.2.11",
      "openssl": "^1.1.0"
    },

    "build": [ /* array of build steps */ ]
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `version` | Yes | Library version |
| `description` | No | Brief description |
| `author` | No | Author name and email |
| `license` | No | SPDX license identifier |
| `homepage` | No | Project homepage URL |
| `source` | Yes | Array of source specifications |
| `dependencies` | No | Map of dependency name to version constraint |
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
| `dest` | No | Destination directory relative to `${SOURCE}` |

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
| `dest` | No | Destination directory relative to `${SOURCE}` |

#### File Source

```json
{
  "type": "file",
  "url": "https://example.org/fix.patch",
  "sha256": "...",
  "dest": "patches/fix.patch"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Must be `"file"` |
| `url` | Yes | URL to download |
| `sha256` | No | SHA256 checksum for integrity verification |
| `dest` | No | Destination path relative to `${SOURCE}` |

#### Local Source

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
| `dest` | No | Destination directory relative to `${SOURCE}` |

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
  "workdir": "lib"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `run` | Yes | Command as array of strings (avoids shell quoting issues) |
| `when` | No | Condition for running this step |
| `env` | No | Step-specific environment variables |
| `workdir` | No | Working directory relative to `${SOURCE}` |

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

Only `${VAR}` syntax is supported. Variables are expanded in `run` array elements.

| Variable | Description |
|----------|-------------|
| `${PREFIX}` | Installation prefix (`$MOON_HOME`) |
| `${DESTDIR}` | Staging directory for installation (temp directory managed by moon-clib) |
| `${JOBS}` | Parallel job count |
| `${SOURCE}` | Source directory (`$MOON_HOME/src/{name}-{version}/`) containing all downloaded sources |
| `${OS}` | Current OS (`darwin`, `linux`, `windows`) |
| `${ARCH}` | Current architecture (`x86_64`, `aarch64`, etc.) |

### Command Execution

Each build step runs with:
- **cwd** = `${SOURCE}/{workdir}` (or just `${SOURCE}` if `workdir` is omitted)
- **env** = inherited environment + step-specific `env` + variables above

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

Using `${SOURCE}` provides better readability than relative paths with multiple `..`:

## Examples

### c-ares (CMake library)

```json
{
  "c-ares": {
    "version": "1.24.0",
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
        "workdir": "c-ares"
      },
      {
        "run": ["cmake", "--build", "build", "-j${JOBS}"],
        "workdir": "c-ares"
      },
      {
        "run": ["cmake", "--install", "build", "--prefix", "${DESTDIR}${PREFIX}"],
        "workdir": "c-ares"
      }
    ]
  }
}
```

### OpenSSL (platform-specific build)

```json
{
  "openssl": {
    "version": "3.2.0",
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
      "zlib": ">=1.2.11"
    },

    "build": [
      {
        "when": { "os": "linux", "arch": "x86_64" },
        "run": ["./Configure", "linux-x86_64", "--prefix=${PREFIX}", "shared", "zlib"],
        "workdir": "openssl"
      },
      {
        "when": { "os": "linux", "arch": "aarch64" },
        "run": ["./Configure", "linux-aarch64", "--prefix=${PREFIX}", "shared", "zlib"],
        "workdir": "openssl"
      },
      {
        "when": { "os": "darwin", "arch": "x86_64" },
        "run": ["./Configure", "darwin64-x86_64-cc", "--prefix=${PREFIX}", "shared", "zlib"],
        "workdir": "openssl"
      },
      {
        "when": { "os": "darwin", "arch": "aarch64" },
        "run": ["./Configure", "darwin64-arm64-cc", "--prefix=${PREFIX}", "shared", "zlib"],
        "workdir": "openssl"
      },
      {
        "run": ["make", "-j${JOBS}"],
        "workdir": "openssl"
      },
      {
        "run": ["make", "install_sw", "install_ssldirs", "DESTDIR=${DESTDIR}"],
        "workdir": "openssl"
      }
    ]
  }
}
```

### Library with Patch File

```json
{
  "example-lib": {
    "version": "1.0.0",

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
        "url": "https://example.org/patches/fix-build.patch",
        "sha256": "...",
        "dest": "patches/fix-build.patch"
      }
    ],

    "build": [
      {
        "run": ["patch", "-p1", "-i", "${SOURCE}/patches/fix-build.patch"],
        "workdir": "lib"
      },
      {
        "run": ["./configure", "--prefix=${PREFIX}"],
        "workdir": "lib"
      },
      {
        "run": ["make", "-j${JOBS}"],
        "workdir": "lib"
      },
      {
        "run": ["make", "install", "DESTDIR=${DESTDIR}"],
        "workdir": "lib"
      }
    ]
  }
}
```

Note: `${SOURCE}/patches/fix-build.patch` is clearer than `../patches/fix-build.patch`, especially when `workdir` is nested deeper.

### Example: Manual Installation (no DESTDIR support)

```json
{
  "simple-lib": {
    "version": "1.0.0",

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
        "workdir": "simple"
      },
      {
        "run": ["install", "-Dm755", "libsimple.so", "${DESTDIR}${PREFIX}/lib/libsimple.so"],
        "workdir": "simple"
      },
      {
        "run": ["install", "-Dm644", "simple.h", "${DESTDIR}${PREFIX}/include/simple.h"],
        "workdir": "simple"
      }
    ]
  }
}
```

## CLI Interface

### Commands

```
moon-clib                  # Install all libraries from moon.lib.json
moon-clib --force          # Reinstall even if already installed
moon-clib list             # List installed libraries
moon-clib info <name>      # Show info about a library
moon-clib remove <name>    # Remove an installed library
```

### Behavior

1. Reads `moon.lib.json` from current directory
2. Resolves dependencies (topological sort)
3. For each library:
   - Checks manifest for existing installation
   - Skips if version matches (unless `--force`)
   - Creates `${SOURCE}` directory (`$MOON_HOME/src/{name}-{version}/`)
   - Creates temporary `${DESTDIR}` directory
   - Downloads all sources to their `dest` paths within `${SOURCE}`
   - Executes build steps with condition matching
   - Scans `${DESTDIR}` to discover installed files
   - Copies files from `${DESTDIR}` to `${PREFIX}`
   - Updates manifest with file list
   - Cleans up `${DESTDIR}`

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

1. moon-clib creates a temporary `${DESTDIR}` directory
2. Build steps install files to `${DESTDIR}${PREFIX}/...`
3. After build completes, moon-clib scans `${DESTDIR}` to discover installed files
4. Files are copied from `${DESTDIR}` to `${PREFIX}` (the real `$MOON_HOME`)
5. The file list is recorded in the manifest

This enables:
- **Clean uninstall**: `moon-clib remove <name>` can delete exactly the files that were installed
- **Conflict detection**: Warn if a new library would overwrite files from another library
