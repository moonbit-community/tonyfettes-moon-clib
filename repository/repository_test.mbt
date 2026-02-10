///| Tests for repository module

///|
/// Counter for unique test directory names
let test_counter : Ref[Int] = Ref::new(0)

///|
/// Create a unique temporary path under /tmp.
fn unique_tmp_path(prefix : String) -> String {
  let id = test_counter.val
  test_counter.val = id + 1
  "/tmp/moon-clib-repo-test-\{prefix}-\{id}"
}

///|
/// Run a git command and fail the current test on non-zero exit.
async fn run_git_or_fail(args : FixedArray[String]) -> Unit {
  let (exit_code, output) = @process.collect_stdout("git", args[:])
  if exit_code != 0 {
    fail("git command failed: \{output.text()}")
  }
}

///|
/// Create a local git remote (file:// URL) with a single package manifest.
async fn create_git_remote_fixture() -> (String, String) {
  let base = unique_tmp_path("fixture")
  let remote = base + "/remote.git"
  let worktree = base + "/worktree"
  @fs.rmdir(base, recursive=true) catch {
    _ => ()
  }
  @fs.mkdir(base, permission=0o755, recursive=true)

  run_git_or_fail(["init", "--bare", remote])
  run_git_or_fail(["init", worktree])

  let pkg_dir = worktree + "/zlib/1.0.0"
  @fs.mkdir(pkg_dir, permission=0o755, recursive=true)
  @fs.write_file(
    pkg_dir + "/manifest.json",
    (
      #|{"source":[],"build":[]}
    ),
    create=0o644,
  )

  run_git_or_fail(["-C", worktree, "add", "."])
  run_git_or_fail([
    "-C", worktree, "-c", "user.email=test@example.com", "-c", "user.name=moon-clib-test",
    "commit", "-m", "init",
  ])
  run_git_or_fail(["-C", worktree, "remote", "add", "origin", remote])
  run_git_or_fail(["-C", worktree, "push", "origin", "HEAD"])

  ("file://\{remote}", base)
}

///|
/// Test Repository::new detects local path
async test "Repository::new detects existing local path" {
  // Use a path that should exist on the system
  let home = @env.get_home_dir()
  let repo = @repository.Repository::new(home)
  assert_true(repo.is_local)
  assert_eq(repo.url, home)
}

///|
/// Test Repository::new detects non-existent path as remote
async test "Repository::new detects remote url" {
  let repo = @repository.Repository::new("https://github.com/example/packages")
  assert_false(repo.is_local)
  assert_eq(repo.url, "https://github.com/example/packages")
}

///|
/// Test Repository::new detects non-existent local path as remote
async test "Repository::new non-existent path is remote" {
  let repo = @repository.Repository::new(
    "/nonexistent/path/that/should/not/exist",
  )
  assert_false(repo.is_local)
}

///|
/// Test validate_repository accepts an existing local directory
async test "validate_repository accepts local directory" {
  let home = @env.get_home_dir()
  @repository.validate_repository(home)
}

///|
/// Test validate_repository rejects an invalid git remote input
async test "validate_repository rejects invalid git remote" {
  let result : Result[Unit, Error] = Ok(
    @repository.validate_repository("moon-clib-invalid-remote-should-fail"),
  ) catch {
    err => Err(err)
  }
  match result {
    Ok(_) => fail("Expected validation to fail")
    Err(err) =>
      match err {
        @repository.FetchError(_) => ()
        _ => fail("Expected FetchError")
      }
  }
}

///|
/// Test validate_repository accepts a valid git remote URL
async test "validate_repository accepts git remote" {
  let (remote_url, fixture_dir) = create_git_remote_fixture()
  @repository.validate_repository(remote_url)
  @fs.rmdir(fixture_dir, recursive=true) catch {
    _ => ()
  }
}

///|
/// Test resolve_repository clones a git remote into local cache
async test "resolve_repository clones git remote" {
  let (remote_url, fixture_dir) = create_git_remote_fixture()
  let repo = @repository.resolve_repository(remote_url)
  assert_true(repo.is_local)
  assert_true(@fs.exists(repo.url))
  let manifest = @repository.fetch_manifest(repo, "zlib", "1.0.0")
  assert_eq(manifest.source.length(), 0)
  assert_eq(manifest.build.length(), 0)
  @fs.rmdir(repo.url, recursive=true) catch {
    _ => ()
  }
  @fs.rmdir(fixture_dir, recursive=true) catch {
    _ => ()
  }
}

///|
/// Test resolve_repository keeps a local path unchanged
async test "resolve_repository local path unchanged" {
  let home = @env.get_home_dir()
  let repo = @repository.resolve_repository(home)
  assert_true(repo.is_local)
  assert_eq(repo.url, home)
}

///|
/// Test Repository equality
test "Repository equality" {
  let repo1 : @repository.Repository = {
    url: "https://example.com",
    is_local: false,
  }
  let repo2 : @repository.Repository = {
    url: "https://example.com",
    is_local: false,
  }
  let repo3 : @repository.Repository = {
    url: "https://other.com",
    is_local: false,
  }
  assert_eq(repo1, repo2)
  assert_not_eq(repo1, repo3)
}

///|
/// Test Repository show
test "Repository show" {
  let repo : @repository.Repository = {
    url: "https://example.com/packages",
    is_local: false,
  }
  let s = repo.to_string()
  assert_true(s.contains("https://example.com/packages"))
  assert_true(s.contains("false"))
}

///|
/// Test find_package returns PackageNotFound for empty repos
async test "find_package empty repos raises error" {
  let repos : Array[@repository.Repository] = []
  let result = @repository.find_package(repos, "nonexistent", "1.0.0") catch {
    @repository.PackageNotFound(name, version) => {
      assert_eq(name, "nonexistent")
      assert_eq(version, "1.0.0")
      return
    }
    _ => panic()
  }
  let _ = result
  panic()
}

///|
/// Test find_package returns PackageNotFound when no repo has package
async test "find_package not found in any repo" {
  // Create repos pointing to non-existent paths
  let repos : Array[@repository.Repository] = [
    { url: "/tmp/nonexistent-repo-1", is_local: true },
    { url: "/tmp/nonexistent-repo-2", is_local: true },
  ]
  let result = @repository.find_package(repos, "missing-pkg", "1.0.0") catch {
    @repository.PackageNotFound(name, version) => {
      assert_eq(name, "missing-pkg")
      assert_eq(version, "1.0.0")
      return
    }
    _ => panic()
  }
  let _ = result
  panic()
}

///|
/// Test fetch_manifest with non-existent local path
async test "fetch_manifest local not found" {
  let repo : @repository.Repository = {
    url: "/tmp/nonexistent-repo",
    is_local: true,
  }
  let result = @repository.fetch_manifest(repo, "test-pkg", "1.0.0") catch {
    @repository.FetchError(_) => return
    _ => panic()
  }
  let _ = result
  panic()
}

///|
/// Test fetch_package_file with non-existent local path
async test "fetch_package_file local not found" {
  let repo : @repository.Repository = {
    url: "/tmp/nonexistent-repo",
    is_local: true,
  }
  let result = @repository.fetch_package_file(
    repo, "test-pkg", "1.0.0", "some-file.patch",
  ) catch {
    @repository.FetchError(_) => return
    _ => panic()
  }
  let _ = result
  panic()
}
