///| Tests for repository module

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
