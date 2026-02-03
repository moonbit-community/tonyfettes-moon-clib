///| Tests for installer module

///| Note: These tests share a manifest file, so they need to be careful about

///| concurrent access. Each test uses unique entry names to minimize conflicts.

///|
/// Test load_install_manifest returns valid manifest
async test "load_install_manifest returns valid manifest" {
  let result : Result[@types.InstallManifest, Error] = Ok(
    @installer.load_install_manifest(),
  ) catch {
    err => Err(err)
  }
  match result {
    Ok(manifest) =>
      // Just verify it returns a valid manifest structure
      assert_true(manifest.installed.length() >= 0)
    Err(err) => fail("Failed to load manifest: \{err}")
  }
}

///|
/// Test is_installed returns false for non-existent package
async test "is_installed returns false for non-existent package" {
  let result : Result[Bool, Error] = Ok(
    @installer.is_installed("non-existent-package-xyz-123", "99.99.99"),
  ) catch {
    err => Err(err)
  }
  match result {
    Ok(installed) => assert_false(installed)
    Err(err) => fail("Failed to check is_installed: \{err}")
  }
}

///|
/// Test remove_package raises error for non-existent package
async test "remove_package raises error for non-existent package" {
  let mut raised = false
  @installer.remove_package("non-existent-package-for-removal-xyz") catch {
    @installer.InstallerError::PackageNotInstalled(_) => raised = true
    _ => fail("Expected InstallerError")
  }
  assert_true(raised)
}
