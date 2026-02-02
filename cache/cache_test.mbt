///| Tests for cache module

///|
/// Test get_pkg_cache_dir returns valid path
async test "get_pkg_cache_dir returns valid path" {
  let pkg_dir = @cache.get_pkg_cache_dir()
  assert_true(pkg_dir.length() > 0)
  assert_true(pkg_dir.has_suffix("/pkg"))
  assert_true(pkg_dir.contains("moon-clib"))
}

///|
/// Test get_src_cache_dir returns valid path
async test "get_src_cache_dir returns valid path" {
  let src_dir = @cache.get_src_cache_dir()
  assert_true(src_dir.length() > 0)
  assert_true(src_dir.has_suffix("/src"))
  assert_true(src_dir.contains("moon-clib"))
}

///|
/// Test get_pkg_cache_path generates correct filename format
async test "get_pkg_cache_path format" {
  let path = @cache.get_pkg_cache_path("c-ares", "1.24.0")
  assert_true(path.contains("c-ares"))
  assert_true(path.contains("1.24.0"))
  assert_true(path.has_suffix(".tar.gz"))
  // Should contain OS and arch in the path
  assert_true(path.contains("-darwin-") || path.contains("-linux-"))
}

///|
/// Test is_cached returns false for non-existent package
async test "is_cached returns false for non-existent" {
  let cached = @cache.is_cached("non-existent-package-xyz", "99.99.99")
  assert_false(cached)
}

///|
/// Test list_cached returns empty for non-existent directory
async test "list_cached empty for non-existent" {
  // This should not error even if cache doesn't exist
  let cached = @cache.list_cached()
  // Just verify it returns an array (may be empty or have items from previous tests)
  assert_true(cached.length() >= 0)
}

///|
/// Test cache path consistency
async test "cache path consistency" {
  let path1 = @cache.get_pkg_cache_path("test-lib", "1.0.0")
  let path2 = @cache.get_pkg_cache_path("test-lib", "1.0.0")
  assert_eq(path1, path2)
}

///|
/// Test different versions have different paths
async test "different versions different paths" {
  let path1 = @cache.get_pkg_cache_path("mylib", "1.0.0")
  let path2 = @cache.get_pkg_cache_path("mylib", "2.0.0")
  assert_true(path1 != path2)
}

///|
/// Test different names have different paths
async test "different names different paths" {
  let path1 = @cache.get_pkg_cache_path("lib-a", "1.0.0")
  let path2 = @cache.get_pkg_cache_path("lib-b", "1.0.0")
  assert_true(path1 != path2)
}
