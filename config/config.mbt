///| Configuration management for moon-clib

///|
/// Error type for config operations
pub suberror ConfigError {
  ConfigError(String)
}

///| Load the global config from the config directory.

///|
/// If the config file doesn't exist, returns a default Config with empty repositories array.
pub async fn load_config() -> @types.Config {
  let config_dir = @env.get_config_dir()
  let config_path = config_dir + "/config.json"
  let content = @fs.read_file(config_path).text() catch {
    _ =>
      // Config file doesn't exist, return default
      return { repositories: [] }
  }
  let json = @json.parse(content) catch {
    err => raise ConfigError("Failed to parse config.json: \{err}")
  }
  @json.from_json(json) catch {
    err => raise ConfigError("Failed to decode config.json: \{err}")
  }
}

///|
/// Save the config to the config directory.
pub async fn save_config(config : @types.Config) -> Unit {
  let config_dir = @env.get_config_dir()
  let config_path = config_dir + "/config.json"
  // Ensure the config directory exists
  @fs.mkdir(config_dir, permission=0o755, recursive=true) catch {
    _ => () // Directory may already exist, ignore error
  }
  let json = config.to_json()
  let content = json.stringify(indent=2)
  @fs.write_file(config_path, content, create=0o644) catch {
    err => raise ConfigError("Failed to write config.json: \{err}")
  }
}

///|
/// Load project dependencies from moon.lib.json in the current directory.
pub async fn load_project_deps() -> @types.ProjectDependencies {
  load_project_deps_from("./moon.lib.json")
}

///|
/// Load project dependencies from a specified path.
pub async fn load_project_deps_from(
  path : String,
) -> @types.ProjectDependencies {
  let content = @fs.read_file(path).text() catch {
    err => raise ConfigError("Failed to read \{path}: \{err}")
  }
  let json = @json.parse(content) catch {
    err => raise ConfigError("Failed to parse \{path}: \{err}")
  }
  @json.from_json(json) catch {
    err => raise ConfigError("Failed to decode \{path}: \{err}")
  }
}
