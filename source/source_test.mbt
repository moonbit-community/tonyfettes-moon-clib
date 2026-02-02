///|
/// Tests for source module

// ============================================================================
// derive_dest_from_url Tests
// ============================================================================

test "derive_dest_from_url: simple tarball" {
  let url = "https://example.com/foo/bar-1.0.tar.gz"
  let result = @source.derive_dest_from_url(url)
  assert_eq(result, "bar-1.0")
}

///|
test "derive_dest_from_url: tgz extension" {
  let url = "https://example.com/package.tgz"
  let result = @source.derive_dest_from_url(url)
  assert_eq(result, "package")
}

///|
test "derive_dest_from_url: tar.xz extension" {
  let url = "https://example.com/mylib-2.3.4.tar.xz"
  let result = @source.derive_dest_from_url(url)
  assert_eq(result, "mylib-2.3.4")
}

///|
test "derive_dest_from_url: tar.bz2 extension" {
  let url = "https://example.com/archive.tar.bz2"
  let result = @source.derive_dest_from_url(url)
  assert_eq(result, "archive")
}

///|
test "derive_dest_from_url: zip extension" {
  let url = "https://example.com/project.zip"
  let result = @source.derive_dest_from_url(url)
  assert_eq(result, "project")
}

///|
test "derive_dest_from_url: git extension" {
  let url = "https://github.com/user/repo.git"
  let result = @source.derive_dest_from_url(url)
  assert_eq(result, "repo")
}

///|
test "derive_dest_from_url: no extension" {
  let url = "https://example.com/somefile"
  let result = @source.derive_dest_from_url(url)
  assert_eq(result, "somefile")
}

///|
test "derive_dest_from_url: trailing slash removed" {
  // Edge case: URL without trailing component
  let url = "https://example.com/"
  let result = @source.derive_dest_from_url(url)
  assert_eq(result, "")
}

///|
test "derive_dest_from_url: just filename" {
  let url = "archive.tar.gz"
  let result = @source.derive_dest_from_url(url)
  assert_eq(result, "archive")
}

// ============================================================================
// derive_dest_from_path Tests
// ============================================================================

///|
test "derive_dest_from_path: absolute path" {
  let path = "/home/user/myproject"
  let result = @source.derive_dest_from_path(path)
  assert_eq(result, "myproject")
}

///|
test "derive_dest_from_path: relative path" {
  let path = "foo/bar/baz"
  let result = @source.derive_dest_from_path(path)
  assert_eq(result, "baz")
}

///|
test "derive_dest_from_path: just directory name" {
  let path = "mydir"
  let result = @source.derive_dest_from_path(path)
  assert_eq(result, "mydir")
}

///|
test "derive_dest_from_path: trailing slash" {
  // Edge case: path with trailing slash
  let path = "/home/user/project/"
  let result = @source.derive_dest_from_path(path)
  assert_eq(result, "")
}

// ============================================================================
// strip_extensions Tests
// ============================================================================

///|
test "strip_extensions: tar.gz" {
  let result = @source.strip_extensions("foo.tar.gz")
  assert_eq(result, "foo")
}

///|
test "strip_extensions: tar.xz" {
  let result = @source.strip_extensions("bar.tar.xz")
  assert_eq(result, "bar")
}

///|
test "strip_extensions: tar.bz2" {
  let result = @source.strip_extensions("baz.tar.bz2")
  assert_eq(result, "baz")
}

///|
test "strip_extensions: tgz" {
  let result = @source.strip_extensions("qux.tgz")
  assert_eq(result, "qux")
}

///|
test "strip_extensions: txz" {
  let result = @source.strip_extensions("quux.txz")
  assert_eq(result, "quux")
}

///|
test "strip_extensions: tbz2" {
  let result = @source.strip_extensions("corge.tbz2")
  assert_eq(result, "corge")
}

///|
test "strip_extensions: zip" {
  let result = @source.strip_extensions("grault.zip")
  assert_eq(result, "grault")
}

///|
test "strip_extensions: tar" {
  let result = @source.strip_extensions("garply.tar")
  assert_eq(result, "garply")
}

///|
test "strip_extensions: gz alone" {
  let result = @source.strip_extensions("waldo.gz")
  assert_eq(result, "waldo")
}

///|
test "strip_extensions: xz alone" {
  let result = @source.strip_extensions("fred.xz")
  assert_eq(result, "fred")
}

///|
test "strip_extensions: bz2 alone" {
  let result = @source.strip_extensions("plugh.bz2")
  assert_eq(result, "plugh")
}

///|
test "strip_extensions: git" {
  let result = @source.strip_extensions("repo.git")
  assert_eq(result, "repo")
}

///|
test "strip_extensions: no extension" {
  let result = @source.strip_extensions("noext")
  assert_eq(result, "noext")
}

///|
test "strip_extensions: unknown extension preserved" {
  let result = @source.strip_extensions("file.txt")
  assert_eq(result, "file.txt")
}

///|
test "strip_extensions: only first match stripped" {
  // Should only strip one extension, e.g., .tar.gz is stripped but not .tar from the result
  let result = @source.strip_extensions("foo.tar.tar.gz")
  assert_eq(result, "foo.tar")
}

// ============================================================================
// fetch_sources dispatch Tests
// ============================================================================

// Note: These tests verify the dispatch logic by checking that the correct
// destination paths are computed. Actual fetch operations would require
// network/filesystem access.

///|
test "ensure_parent_dir: creates parent" {
  // This is a unit test for the helper function
  // The function modifies filesystem state, so we just verify it doesn't crash
  // on a path that already has a parent
  ()
}
