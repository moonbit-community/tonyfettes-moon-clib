// Test helpers
///|
fn[T : @json.FromJson + ToJson + Eq] roundtrip(value : T) -> Bool {
  let json = value.to_json()
  let parsed : T = @json.from_json(json) catch { _ => return false }
  parsed == value
}

// Condition tests

///|
test "Condition: empty" {
  let cond : @types.Condition = { os: None, arch: None }
  assert_true(roundtrip(cond))
}

///|
test "Condition: os only" {
  let cond : @types.Condition = { os: Some("linux"), arch: None }
  assert_true(roundtrip(cond))
  let json = cond.to_json()
  guard json is Object(obj) else { panic() }
  assert_eq(obj.get("os"), Some(Json::string("linux")))
}

///|
test "Condition: arch only" {
  let cond : @types.Condition = { os: None, arch: Some("x86_64") }
  assert_true(roundtrip(cond))
}

///|
test "Condition: both fields" {
  let cond : @types.Condition = { os: Some("darwin"), arch: Some("aarch64") }
  assert_true(roundtrip(cond))
}

// BuildStep tests

///|
test "BuildStep: minimal" {
  let step : @types.BuildStep = {
    run: ["make"],
    when: None,
    env: None,
    cwd: None,
  }
  assert_true(roundtrip(step))
}

///|
test "BuildStep: with condition" {
  let step : @types.BuildStep = {
    run: ["./configure", "--prefix=$PREFIX"],
    when: Some({ os: Some("linux"), arch: None }),
    env: None,
    cwd: Some("src"),
  }
  assert_true(roundtrip(step))
}

///|
test "BuildStep: with env" {
  let env : Map[String, String] = {}
  env["CC"] = "clang"
  env["CFLAGS"] = "-O2"
  let step : @types.BuildStep = {
    run: ["make", "-j4"],
    when: None,
    env: Some(env),
    cwd: None,
  }
  assert_true(roundtrip(step))
}

// TarballSource tests

///|
test "TarballSource: full" {
  let src : @types.TarballSource = {
    url: "https://example.org/lib-1.0.tar.gz",
    sha256: Some("abc123"),
    strip_components: Some(1),
    dest: Some("lib"),
  }
  assert_true(roundtrip(src))
}

///|
test "TarballSource: minimal" {
  let src : @types.TarballSource = {
    url: "https://example.org/lib.tar.gz",
    sha256: None,
    strip_components: None,
    dest: None,
  }
  assert_true(roundtrip(src))
}

// GitSource tests

///|
test "GitSource: full" {
  let src : @types.GitSource = {
    url: "https://github.com/org/repo.git",
    ref_: "v1.0.0",
    shallow: Some(true),
    dest: Some("repo"),
  }
  assert_true(roundtrip(src))
}

///|
test "GitSource: minimal" {
  let src : @types.GitSource = {
    url: "https://github.com/org/repo.git",
    ref_: "main",
    shallow: None,
    dest: None,
  }
  assert_true(roundtrip(src))
}

///|
test "GitSource: JSON uses 'ref' field" {
  let src : @types.GitSource = {
    url: "https://github.com/org/repo.git",
    ref_: "v1.0.0",
    shallow: None,
    dest: None,
  }
  let json = src.to_json()
  guard json is Object(obj) else { panic() }
  // Should use "ref" not "ref_" in JSON
  assert_eq(obj.get("ref"), Some(Json::string("v1.0.0")))
  assert_eq(obj.get("ref_"), None)
}

// FileSource tests

///|
test "FileSource: with url" {
  let src : @types.FileSource = {
    url: Some("https://example.org/patch.diff"),
    path: None,
    sha256: Some("xyz789"),
    dest: Some("patches/fix.patch"),
  }
  assert_true(roundtrip(src))
}

///|
test "FileSource: with path" {
  let src : @types.FileSource = {
    url: None,
    path: Some("fix-build.patch"),
    sha256: None,
    dest: Some("patches/fix-build.patch"),
  }
  assert_true(roundtrip(src))
}

// LocalSource tests

///|
test "LocalSource: full" {
  let src : @types.LocalSource = { path: "./vendor/lib", dest: Some("vendor") }
  assert_true(roundtrip(src))
}

///|
test "LocalSource: minimal" {
  let src : @types.LocalSource = { path: "/home/user/lib", dest: None }
  assert_true(roundtrip(src))
}

// Source enum tests

///|
test "Source: Tarball serializes with type field" {
  let src : @types.Source = @types.Source::Tarball({
    url: "https://example.org/lib.tar.gz",
    sha256: None,
    strip_components: None,
    dest: None,
  })
  let json = src.to_json()
  guard json is Object(obj) else { panic() }
  assert_eq(obj.get("type"), Some(Json::string("tarball")))
  assert_eq(
    obj.get("url"),
    Some(Json::string("https://example.org/lib.tar.gz")),
  )
}

///|
test "Source: Git serializes with type field" {
  let src : @types.Source = @types.Source::Git({
    url: "https://github.com/org/repo.git",
    ref_: "v1.0",
    shallow: None,
    dest: None,
  })
  let json = src.to_json()
  guard json is Object(obj) else { panic() }
  assert_eq(obj.get("type"), Some(Json::string("git")))
  assert_eq(obj.get("ref"), Some(Json::string("v1.0")))
}

///|
test "Source: File serializes with type field" {
  let src : @types.Source = @types.Source::File({
    url: Some("https://example.org/fix.patch"),
    path: None,
    sha256: None,
    dest: None,
  })
  let json = src.to_json()
  guard json is Object(obj) else { panic() }
  assert_eq(obj.get("type"), Some(Json::string("file")))
}

///|
test "Source: Local serializes with type field" {
  let src : @types.Source = @types.Source::Local({
    path: "./vendor",
    dest: None,
  })
  let json = src.to_json()
  guard json is Object(obj) else { panic() }
  assert_eq(obj.get("type"), Some(Json::string("local")))
}

///|
test "Source: Tarball roundtrip" {
  let src : @types.Source = @types.Source::Tarball({
    url: "https://example.org/lib-1.0.tar.gz",
    sha256: Some("abc123"),
    strip_components: Some(1),
    dest: Some("lib"),
  })
  assert_true(roundtrip(src))
}

///|
test "Source: Git roundtrip" {
  let src : @types.Source = @types.Source::Git({
    url: "https://github.com/org/repo.git",
    ref_: "v1.0.0",
    shallow: Some(true),
    dest: Some("repo"),
  })
  assert_true(roundtrip(src))
}

///|
test "Source: File roundtrip with url" {
  let src : @types.Source = @types.Source::File({
    url: Some("https://example.org/patch.diff"),
    path: None,
    sha256: Some("xyz"),
    dest: Some("patches/fix.patch"),
  })
  assert_true(roundtrip(src))
}

///|
test "Source: File roundtrip with path" {
  let src : @types.Source = @types.Source::File({
    url: None,
    path: Some("fix.patch"),
    sha256: None,
    dest: None,
  })
  assert_true(roundtrip(src))
}

///|
test "Source: Local roundtrip" {
  let src : @types.Source = @types.Source::Local({
    path: "./vendor/lib",
    dest: Some("vendor"),
  })
  assert_true(roundtrip(src))
}

///|
test "Source: File validation - error on neither url nor path" {
  let json : Json = { "type": "file", "dest": "patches/fix.patch" }
  let result : Result[@types.Source, _] = Ok(@json.from_json(json)) catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

///|
test "Source: File validation - error on both url and path" {
  let json : Json = {
    "type": "file",
    "url": "https://example.org/fix.patch",
    "path": "local-fix.patch",
    "dest": "patches/fix.patch",
  }
  let result : Result[@types.Source, _] = Ok(@json.from_json(json)) catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

///|
test "Source: unknown type error" {
  let json : Json = { "type": "unknown", "foo": "bar" }
  let result : Result[@types.Source, _] = Ok(@json.from_json(json)) catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

// PackageManifest tests

///|
test "PackageManifest: full example from DESIGN.md" {
  let deps : Map[String, String] = {}
  deps["zlib"] = "1.3.1"
  let manifest : @types.PackageManifest = {
    description: Some("A C library for asynchronous DNS requests"),
    author: Some("Daniel Stenberg <daniel@haxx.se>"),
    license: Some("MIT"),
    homepage: Some("https://c-ares.org"),
    source: [
      @types.Source::Tarball({
        url: "https://c-ares.org/download/c-ares-1.24.0.tar.gz",
        sha256: Some(
          "0a72be66959955c43e2af2fbd03418e82a2bd5464604e3e0a6c0dc7d1f1fdc5f",
        ),
        strip_components: Some(1),
        dest: Some("c-ares"),
      }),
    ],
    dependencies: Some(deps),
    build: [
      {
        run: [
          "cmake", "-B", "build", "-DCMAKE_INSTALL_PREFIX=$PREFIX", "-DCMAKE_BUILD_TYPE=Release",
        ],
        when: None,
        env: None,
        cwd: Some("c-ares"),
      },
      {
        run: ["cmake", "--build", "build", "-j$JOBS"],
        when: None,
        env: None,
        cwd: Some("c-ares"),
      },
    ],
  }
  assert_true(roundtrip(manifest))
}

///|
test "PackageManifest: minimal" {
  let manifest : @types.PackageManifest = {
    description: None,
    author: None,
    license: None,
    homepage: None,
    source: [],
    dependencies: None,
    build: [],
  }
  assert_true(roundtrip(manifest))
}

// ProjectDependencies tests

///|
test "ProjectDependencies: roundtrip" {
  let deps : Map[String, String] = {}
  deps["c-ares"] = "1.24.0"
  deps["openssl"] = "3.2.0"
  deps["zlib"] = "1.3.1"
  let proj : @types.ProjectDependencies = { dependencies: deps }
  assert_true(roundtrip(proj))
}

// Config tests

///|
test "Config: roundtrip" {
  let config : @types.Config = {
    repositories: [
      "https://github.com/anthropics/moon-clib-packages", "/home/user/my-custom-packages",
    ],
  }
  assert_true(roundtrip(config))
}

///|
test "Config: empty" {
  let config : @types.Config = { repositories: [] }
  assert_true(roundtrip(config))
}

// InstalledLibrary tests

///|
test "InstalledLibrary: roundtrip" {
  let lib : @types.InstalledLibrary = {
    version: "1.24.0",
    installed_at: "2024-01-15T10:30:00Z",
    files: ["lib/libcares.so", "lib/libcares.so.2", "include/ares.h"],
  }
  assert_true(roundtrip(lib))
}

// InstallManifest tests

///|
test "InstallManifest: roundtrip" {
  let libs : Map[String, @types.InstalledLibrary] = {}
  libs["c-ares"] = {
    version: "1.24.0",
    installed_at: "2024-01-15T10:30:00Z",
    files: ["lib/libcares.so", "lib/libcares.so.2", "include/ares.h"],
  }
  libs["zlib"] = {
    version: "1.3.1",
    installed_at: "2024-01-15T10:31:00Z",
    files: ["lib/libz.so", "include/zlib.h"],
  }
  let manifest : @types.InstallManifest = { installed: libs }
  assert_true(roundtrip(manifest))
}

///|
test "InstallManifest: empty" {
  let manifest : @types.InstallManifest = { installed: {} }
  assert_true(roundtrip(manifest))
}

// JSON parsing tests

///|
test "Source: parse from JSON string - tarball" {
  let json_str =
    #|{"type": "tarball", "url": "https://example.org/lib.tar.gz", "sha256": "abc123"}
  let json : Json = @json.parse(json_str) catch { _ => panic() }
  let src : @types.Source = @json.from_json(json) catch { _ => panic() }
  guard src is @types.Source::Tarball(t) else { panic() }
  assert_eq(t.url, "https://example.org/lib.tar.gz")
  assert_eq(t.sha256, Some("abc123"))
}

///|
test "Source: parse from JSON string - git" {
  let json_str =
    #|{"type": "git", "url": "https://github.com/org/repo.git", "ref": "v1.0", "shallow": true}
  let json : Json = @json.parse(json_str) catch { _ => panic() }
  let src : @types.Source = @json.from_json(json) catch { _ => panic() }
  guard src is @types.Source::Git(g) else { panic() }
  assert_eq(g.url, "https://github.com/org/repo.git")
  assert_eq(g.ref_, "v1.0")
  assert_eq(g.shallow, Some(true))
}

///|
test "BuildStep: parse with condition" {
  let json_str =
    #|{"run": ["./configure"], "when": {"os": "linux"}, "cwd": "src"}
  let json : Json = @json.parse(json_str) catch { _ => panic() }
  let step : @types.BuildStep = @json.from_json(json) catch { _ => panic() }
  assert_eq(step.run, ["./configure"])
  guard step.when is Some(cond) else { panic() }
  assert_eq(cond.os, Some("linux"))
  assert_eq(cond.arch, None)
  assert_eq(step.cwd, Some("src"))
}
