///| Package caching for moon-clib

///| Manages built package tarballs and source directories

///|
/// Error type for cache operations
pub suberror CacheError {
  CreateDir(String, String)
  CreateTarball(String, String)
  CacheFileNotFound(String)
  ExtractTarball(String, String)
  CleanFailed(String)
}

///|
/// Human-readable error output
pub impl Show for CacheError with output(
  self : CacheError,
  logger : &@builtin.Logger,
) -> Unit {
  match self {
    CreateDir(path, _) => logger.write_string("Failed to create directory " + path)
    CreateTarball(path, _) =>
      logger.write_string("Failed to create tarball " + path)
    CacheFileNotFound(path) => logger.write_string("Cache file not found: " + path)
    ExtractTarball(path, _) =>
      logger.write_string("Failed to extract tarball " + path)
    CleanFailed(kind) => logger.write_string("Failed to clean " + kind + " cache")
  }
}

///| Get the package cache directory (for built tarballs).

///|
/// Returns: {cache_dir}/pkg/
pub async fn get_pkg_cache_dir() -> String {
  let cache_dir = @env.get_cache_dir()
  cache_dir + "/pkg"
}

///| Get the source cache directory (for extracted sources).

///|
/// Returns: {cache_dir}/src/
pub async fn get_src_cache_dir() -> String {
  let cache_dir = @env.get_cache_dir()
  cache_dir + "/src"
}

///| Get the cache path for a specific package.

///|
/// Returns: {cache_dir}/pkg/{name}-{version}-{os}-{arch}.tar.gz
pub async fn get_pkg_cache_path(name : String, version : String) -> String {
  let pkg_dir = get_pkg_cache_dir()
  let os = @env.get_os()
  let arch = @env.get_arch()
  pkg_dir + "/" + name + "-" + version + "-" + os + "-" + arch + ".tar.gz"
}

///|
/// Check if a package is already cached.
pub async fn is_cached(name : String, version : String) -> Bool {
  let cache_path = get_pkg_cache_path(name, version) catch { _ => return false }
  file_exists(cache_path)
}

///|
/// Check if a file exists using test -f command.
async fn file_exists(path : String) -> Bool {
  let (exit_code, _) = @process.collect_stdout("test", ["-f", path])
  exit_code == 0
}

///|
/// Check if a directory exists using test -d command.
async fn dir_exists(path : String) -> Bool {
  let (exit_code, _) = @process.collect_stdout("test", ["-d", path])
  exit_code == 0
}

///|
/// Ensure a directory exists, creating it if necessary.
async fn ensure_dir(path : String) -> Unit {
  if not(dir_exists(path)) {
    let (exit_code, output) = @process.collect_stdout("mkdir", ["-p", path])
    if exit_code != 0 {
      let msg = output.text()
      raise CreateDir(path, msg)
    }
  }
}

///| Save build output to cache as a tarball.

///|
/// Creates {cache_dir}/pkg/{name}-{version}-{os}-{arch}.tar.gz from install root.
pub async fn save_to_cache(
  name : String,
  version : String,
  install_root : String,
) -> Unit {
  let cache_path = get_pkg_cache_path(name, version)
  let pkg_dir = get_pkg_cache_dir()
  // Ensure the package cache directory exists
  ensure_dir(pkg_dir)
  // Create tarball from install root contents
  let (exit_code, output) = @process.collect_stdout("tar", [
    "-czf", cache_path, "-C", install_root, ".",
  ])
  if exit_code != 0 {
    let msg = output.text()
    raise CreateTarball(cache_path, msg)
  }
}

///| Extract a cached package to a prefix directory.

///|
/// Returns the list of extracted files (relative paths).
pub async fn extract_from_cache(
  name : String,
  version : String,
  prefix : String,
) -> Array[String] {
  let cache_path = get_pkg_cache_path(name, version)
  // Check if the cache file exists
  if not(file_exists(cache_path)) {
    raise CacheFileNotFound(cache_path)
  }
  // Ensure the prefix directory exists
  ensure_dir(prefix)
  // Extract tarball to prefix, capturing file list with verbose output
  let (exit_code, output) = @process.collect_stdout("tar", [
    "-xzvf", cache_path, "-C", prefix,
  ])
  if exit_code != 0 {
    let msg = output.text()
    raise ExtractTarball(cache_path, msg)
  }
  // Parse the verbose output to get file list
  let text = output.text()
  let result : Array[String] = []
  for line in text.split("\n") {
    let s = line.to_string()
    if s.is_empty() {
      continue
    }
    // Clean up paths (remove leading ./ if present)
    let cleaned = if s.has_prefix("./") { s[2:].to_string() } else { s }
    if not(cleaned.is_empty()) {
      result.push(cleaned)
    }
  }
  result
}

///| List all cached packages.

///|
/// Returns array of (name, version) tuples parsed from cache filenames.
pub async fn list_cached() -> Array[(String, String)] {
  let pkg_dir = get_pkg_cache_dir()
  // Check if directory exists
  if not(dir_exists(pkg_dir)) {
    return []
  }
  // List all .tar.gz files in the package cache directory
  let entries = @fs.readdir(pkg_dir) catch { _ => return [] }
  let os = @env.get_os()
  let arch = @env.get_arch()
  let suffix = "-" + os + "-" + arch + ".tar.gz"
  // Filter and parse filenames
  let result : Array[(String, String)] = []
  for filename in entries {
    if filename.has_suffix(suffix) {
      // Parse {name}-{version}-{os}-{arch}.tar.gz
      let base = filename[:filename.length() - suffix.length()].to_string()
      // Find the last dash to separate name and version
      // Format: name-version (name may contain dashes, version typically doesn't)
      match parse_name_version(base) {
        Some((name, version)) => result.push((name, version))
        None => continue
      }
    }
  }
  result
}

///| Parse a "{name}-{version}" string into (name, version).

///|
/// Name can contain dashes, version is the part after the last dash.
fn parse_name_version(s : String) -> (String, String)? {
  // Find the last dash
  let last_dash = find_last_dash(s)
  if last_dash < 0 {
    return None
  }
  // Extract name and version using character iteration to avoid slice errors
  let name_buf = StringBuilder::new()
  let version_buf = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if i < last_dash {
      name_buf.write_char(c.to_int().unsafe_to_char())
    } else if i > last_dash {
      version_buf.write_char(c.to_int().unsafe_to_char())
    }
  }
  let name = name_buf.to_string()
  let version = version_buf.to_string()
  if name.is_empty() || version.is_empty() {
    return None
  }
  Some((name, version))
}

///|
/// Find the index of the last dash in a string.
fn find_last_dash(s : String) -> Int {
  let mut last = -1
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == '-' {
      last = i
    }
  }
  last
}

///|
/// Clean the cache by removing all cached packages and sources.
pub async fn clean_cache() -> Unit {
  let cache_dir = @env.get_cache_dir()
  let pkg_dir = cache_dir + "/pkg"
  let src_dir = cache_dir + "/src"
  // Remove pkg directory contents if it exists
  if dir_exists(pkg_dir) {
    let (exit_code, _) = @process.collect_stdout("sh", [
      "-c",
      "rm -rf " + pkg_dir + "/*",
    ])
    // Note: rm -rf with glob may fail if no files match, which is OK
    if exit_code != 0 {
      // Only raise if directory exists and has content
      let entries = @fs.readdir(pkg_dir) catch { _ => [] }
      if entries.length() > 0 {
        raise CleanFailed("pkg")
      }
    }
  }
  // Remove src directory contents if it exists
  if dir_exists(src_dir) {
    let (exit_code, _) = @process.collect_stdout("sh", [
      "-c",
      "rm -rf " + src_dir + "/*",
    ])
    if exit_code != 0 {
      // Only raise if directory exists and has content
      let entries = @fs.readdir(src_dir) catch { _ => [] }
      if entries.length() > 0 {
        raise CleanFailed("src")
      }
    }
  }
}

// Internal tests for helper functions

///|
/// Test parse_name_version with simple name
test "parse_name_version simple" {
  let result = parse_name_version("zlib-1.3.1")
  match result {
    Some((name, version)) => {
      assert_eq(name, "zlib")
      assert_eq(version, "1.3.1")
    }
    None => fail("Expected Some, got None")
  }
}

///|
/// Test parse_name_version with hyphenated name
test "parse_name_version hyphenated name" {
  let result = parse_name_version("c-ares-1.24.0")
  match result {
    Some((name, version)) => {
      assert_eq(name, "c-ares")
      assert_eq(version, "1.24.0")
    }
    None => fail("Expected Some, got None")
  }
}

///|
/// Test parse_name_version with multiple hyphens in name
test "parse_name_version multiple hyphens" {
  let result = parse_name_version("my-cool-lib-2.0.0")
  match result {
    Some((name, version)) => {
      assert_eq(name, "my-cool-lib")
      assert_eq(version, "2.0.0")
    }
    None => fail("Expected Some, got None")
  }
}

///|
/// Test parse_name_version with no dash returns None
test "parse_name_version no dash" {
  let result = parse_name_version("nodash")
  assert_true(result is None)
}

///|
/// Test parse_name_version with empty string returns None
test "parse_name_version empty" {
  let result = parse_name_version("")
  assert_true(result is None)
}

///|
/// Test parse_name_version with trailing dash returns None
test "parse_name_version trailing dash" {
  let result = parse_name_version("name-")
  assert_true(result is None)
}

///|
/// Test parse_name_version with leading dash returns None
test "parse_name_version leading dash" {
  let result = parse_name_version("-version")
  assert_true(result is None)
}

///|
/// Test find_last_dash helper function
test "find_last_dash basic" {
  assert_eq(find_last_dash("a-b-c"), 3)
  assert_eq(find_last_dash("abc"), -1)
  assert_eq(find_last_dash("-"), 0)
  assert_eq(find_last_dash("a-b"), 1)
}
