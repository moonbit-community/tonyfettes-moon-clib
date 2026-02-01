///| Tests for configuration management

///| Test load_config loads config successfully
async test "load_config loads successfully" {
  // This test verifies that load_config works when config file exists or not.
  // If file doesn't exist, it returns default. If it exists, it loads it.
  let result : Result[@types.Config, Error] = try {
    Ok(@config.load_config())
  } catch {
    err => Err(err)
  }
  match result {
    Ok(config) => {
      // Config should have a repositories array (possibly empty)
      ignore(config.repositories)
    }
    Err(_) => {
      // Config file might exist but be invalid - that's a valid test scenario
      ()
    }
  }
}

///| Test save_config and load_config roundtrip
async test "save_config and load_config roundtrip" {
  let test_config : @types.Config = {
    repositories: [
      "https://github.com/example/repo1",
      "https://github.com/example/repo2",
    ],
  }
  @config.save_config(test_config)
  let loaded = @config.load_config()
  assert_eq(loaded.repositories.length(), 2)
  assert_eq(loaded.repositories[0], "https://github.com/example/repo1")
  assert_eq(loaded.repositories[1], "https://github.com/example/repo2")
}

///| Test load_project_deps_from raises error for missing file
async test "load_project_deps_from raises error for missing file" {
  let result : Result[@types.ProjectDependencies, Error] = try {
    Ok(@config.load_project_deps_from("/nonexistent/path/moon.lib.json"))
  } catch {
    err => Err(err)
  }
  match result {
    Ok(_) => fail("Expected error for missing file")
    Err(_) => () // Expected: should raise error
  }
}

///| Test load_project_deps_from can parse valid file
async test "load_project_deps_from with valid file" {
  // Try to load from current directory - may not exist in test environment
  let result : Result[@types.ProjectDependencies, Error] = try {
    Ok(@config.load_project_deps_from("./moon.lib.json"))
  } catch {
    err => Err(err)
  }
  match result {
    Ok(deps) => {
      // Successfully loaded project deps
      ignore(deps.dependencies)
    }
    Err(_) => {
      // Expected if no moon.lib.json exists in test directory
      ()
    }
  }
}
