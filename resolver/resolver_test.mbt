///| Tests for dependency resolver

///| Counter for unique test directory names
let test_counter : Ref[Int] = Ref::new(0)

///| Helper to create a simple manifest with optional dependencies
fn make_manifest(deps : Map[String, String]?) -> @types.PackageManifest {
  {
    description: None,
    author: None,
    license: None,
    homepage: None,
    source: [],
    dependencies: deps,
    build: [],
  }
}

///| Helper to create a mock repository backed by a Map
///| This creates a local repository pointing to a temp directory structure
struct MockRegistry {
  base_path : String
}

///| Parse "name@version" key into (name, version)
fn parse_key(key : String) -> (String, String)? {
  // Find the @ separator
  let mut at_pos = -1
  for i = 0; i < key.length(); i = i + 1 {
    if key[i] == '@' {
      at_pos = i
      break
    }
  }
  if at_pos < 0 {
    return None
  }
  // Extract name and version character by character
  let name_buf = StringBuilder::new()
  let version_buf = StringBuilder::new()
  for i = 0; i < key.length(); i = i + 1 {
    if i < at_pos {
      name_buf.write_char(key[i].to_int().unsafe_to_char())
    } else if i > at_pos {
      version_buf.write_char(key[i].to_int().unsafe_to_char())
    }
  }
  Some((name_buf.to_string(), version_buf.to_string()))
}

///| Create a mock registry with the given packages
async fn MockRegistry::new(
  packages : Map[String, @types.PackageManifest]
) -> MockRegistry raise {
  // Create a temporary directory structure for packages
  let id = test_counter.val
  test_counter.val = id + 1
  let base_path = "/tmp/moon-clib-test-" + id.to_string()

  // Clean up if directory already exists from a previous test run
  try {
    @fs.rmdir(base_path, recursive=true)
  } catch {
    _ => () // Ignore errors - directory may not exist
  }

  @fs.mkdir(base_path, permission=0o755, recursive=true)

  for key, manifest in packages {
    // Parse key as name@version
    guard parse_key(key) is Some((name, version)) else {
      continue
    }

    // Create directory structure
    let pkg_dir = base_path + "/" + name + "/" + version
    @fs.mkdir(pkg_dir, permission=0o755, recursive=true)

    // Write manifest.json
    let manifest_json = manifest.to_json().stringify()
    @fs.write_file(pkg_dir + "/manifest.json", manifest_json, create=0o644)
  }

  { base_path, }
}

///| Get a repository for this mock registry
async fn MockRegistry::repository(self : MockRegistry) -> @repository.Repository {
  @repository.Repository::new(self.base_path)
}

///| Cleanup the mock registry
async fn MockRegistry::cleanup(self : MockRegistry) -> Unit raise {
  @fs.rmdir(self.base_path, recursive=true)
}

///| Get index of package in result by name
fn find_index(result : Array[@resolver.ResolvedPackage], name : String) -> Int {
  for i = 0; i < result.length(); i = i + 1 {
    if result[i].name == name {
      return i
    }
  }
  -1
}

// Test: Single package with no dependencies
async test "resolve: single package no deps" {
  let packages : Map[String, @types.PackageManifest] = {}
  packages["zlib@1.0.0"] = make_manifest(None)

  let registry = MockRegistry::new(packages)
  let repo = registry.repository()

  let deps : Map[String, String] = {}
  deps["zlib"] = "1.0.0"

  let result = @resolver.resolve_dependencies(deps, [repo])
  assert_eq(result.length(), 1)
  assert_eq(result[0].name, "zlib")
  assert_eq(result[0].version, "1.0.0")

  registry.cleanup()
}

// Test: Linear dependency chain (A -> B -> C)
async test "resolve: linear chain A -> B -> C" {
  let packages : Map[String, @types.PackageManifest] = {}

  // C has no deps
  packages["C@1.0.0"] = make_manifest(None)

  // B depends on C
  let b_deps : Map[String, String] = {}
  b_deps["C"] = "1.0.0"
  packages["B@1.0.0"] = make_manifest(Some(b_deps))

  // A depends on B
  let a_deps : Map[String, String] = {}
  a_deps["B"] = "1.0.0"
  packages["A@1.0.0"] = make_manifest(Some(a_deps))

  let registry = MockRegistry::new(packages)
  let repo = registry.repository()

  let deps : Map[String, String] = {}
  deps["A"] = "1.0.0"

  let result = @resolver.resolve_dependencies(deps, [repo])

  // Should have 3 packages
  assert_eq(result.length(), 3)

  // C must come before B, B must come before A
  let c_i = find_index(result, "C")
  let b_i = find_index(result, "B")
  let a_i = find_index(result, "A")

  assert_true(c_i >= 0)
  assert_true(b_i >= 0)
  assert_true(a_i >= 0)
  assert_true(c_i < b_i)
  assert_true(b_i < a_i)

  registry.cleanup()
}

// Test: Diamond dependency (A -> B, A -> C, B -> D, C -> D)
async test "resolve: diamond dependency" {
  let packages : Map[String, @types.PackageManifest] = {}

  // D has no deps (the common dependency)
  packages["D@1.0.0"] = make_manifest(None)

  // B depends on D
  let b_deps : Map[String, String] = {}
  b_deps["D"] = "1.0.0"
  packages["B@1.0.0"] = make_manifest(Some(b_deps))

  // C depends on D
  let c_deps : Map[String, String] = {}
  c_deps["D"] = "1.0.0"
  packages["C@1.0.0"] = make_manifest(Some(c_deps))

  // A depends on B and C
  let a_deps : Map[String, String] = {}
  a_deps["B"] = "1.0.0"
  a_deps["C"] = "1.0.0"
  packages["A@1.0.0"] = make_manifest(Some(a_deps))

  let registry = MockRegistry::new(packages)
  let repo = registry.repository()

  let deps : Map[String, String] = {}
  deps["A"] = "1.0.0"

  let result = @resolver.resolve_dependencies(deps, [repo])

  // Should have 4 packages, D only once
  assert_eq(result.length(), 4)

  // D must come before B and C
  let d_i = find_index(result, "D")
  let b_i = find_index(result, "B")
  let c_i = find_index(result, "C")
  let a_i = find_index(result, "A")

  assert_true(d_i >= 0)
  assert_true(b_i >= 0)
  assert_true(c_i >= 0)
  assert_true(a_i >= 0)
  assert_true(d_i < b_i)
  assert_true(d_i < c_i)
  // B and C must come before A
  assert_true(b_i < a_i)
  assert_true(c_i < a_i)

  registry.cleanup()
}

// Test: Circular dependency detection (A -> B -> A)
async test "resolve: circular dependency error" {
  let packages : Map[String, @types.PackageManifest] = {}

  // B depends on A (creates cycle)
  let b_deps : Map[String, String] = {}
  b_deps["A"] = "1.0.0"
  packages["B@1.0.0"] = make_manifest(Some(b_deps))

  // A depends on B
  let a_deps : Map[String, String] = {}
  a_deps["B"] = "1.0.0"
  packages["A@1.0.0"] = make_manifest(Some(a_deps))

  let registry = MockRegistry::new(packages)
  let repo = registry.repository()

  let deps : Map[String, String] = {}
  deps["A"] = "1.0.0"

  let result : Result[Array[@resolver.ResolvedPackage], Error] = try {
    Ok(@resolver.resolve_dependencies(deps, [repo]))
  } catch {
    e => Err(e)
  }

  // Should fail with circular dependency error
  assert_true(result is Err(_))

  registry.cleanup()
}

// Test: Package not found
async test "resolve: package not found error" {
  let packages : Map[String, @types.PackageManifest] = {}
  // Empty registry

  let registry = MockRegistry::new(packages)
  let repo = registry.repository()

  let deps : Map[String, String] = {}
  deps["nonexistent"] = "1.0.0"

  let result : Result[Array[@resolver.ResolvedPackage], Error] = try {
    Ok(@resolver.resolve_dependencies(deps, [repo]))
  } catch {
    e => Err(e)
  }

  // Should fail with not found error
  assert_true(result is Err(_))

  registry.cleanup()
}

// Test: Multiple top-level dependencies
async test "resolve: multiple top-level deps" {
  let packages : Map[String, @types.PackageManifest] = {}
  packages["zlib@1.0.0"] = make_manifest(None)
  packages["openssl@1.0.0"] = make_manifest(None)

  let registry = MockRegistry::new(packages)
  let repo = registry.repository()

  let deps : Map[String, String] = {}
  deps["zlib"] = "1.0.0"
  deps["openssl"] = "1.0.0"

  let result = @resolver.resolve_dependencies(deps, [repo])

  // Should have both packages
  assert_eq(result.length(), 2)

  let has_zlib = find_index(result, "zlib") >= 0
  let has_openssl = find_index(result, "openssl") >= 0
  assert_true(has_zlib)
  assert_true(has_openssl)

  registry.cleanup()
}
