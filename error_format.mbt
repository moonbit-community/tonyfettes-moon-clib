///|
/// Error formatting for CLI output
fn is_missing_file(path : String, cause : String, filename : String) -> Bool {
  if not(path.has_suffix(filename)) {
    return false
  }
  let missing = cause.contains("No such file") || cause.contains("no such file") || cause.contains("not found")
  missing
}

///|
/// Format errors for user-facing output
pub fn format_error(
  err : Error,
  verbose : Bool,
) -> (String, Array[String], String?) {
  let err_string = err.to_string()
  let hints : Array[String] = []
  let mut detail : String? = None

  let message = match err {
    @cli.ParseError::UnknownCommand(cmd) => {
      hints.push("Run `moon run . --help` to see available commands.")
      "Unknown command: " + cmd
    }
    @cli.ParseError::MissingArgument(msg) => {
      hints.push("Run `moon run . --help` to see required arguments.")
      msg
    }
    @cli.ParseError::UnknownFlag(flag) => {
      hints.push("Run `moon run . --help` to see supported flags.")
      "Unknown flag: " + flag
    }

    @config.ConfigError::ReadFile(path, cause) => {
      detail = Some(cause)
      if is_missing_file(path, cause, "moon.lib.json") {
        hints.push("Create `moon.lib.json` in the current directory.")
        hints.push("Run the command from the project root if needed.")
        "No `moon.lib.json` found in the current directory."
      } else {
        hints.push("Check that the file exists and is readable.")
        "Failed to read " + path
      }
    }
    @config.ConfigError::ParseJson(path, cause) => {
      detail = Some(cause)
      hints.push("Check JSON syntax in " + path + ".")
      "Invalid JSON in " + path
    }
    @config.ConfigError::DecodeJson(path, cause) => {
      detail = Some(cause)
      hints.push("Check required fields and types in " + path + ".")
      "Invalid config format in " + path
    }
    @config.ConfigError::WriteFile(path, cause) => {
      detail = Some(cause)
      hints.push("Check that the path is writable.")
      "Failed to write " + path
    }

    @builder.BuildError::EmptyRunArray => {
      hints.push("Check build steps in the package manifest.")
      "Build step has no command."
    }
    @builder.BuildError::CommandFailed(exit_code, cmd) => {
      detail = Some("exit code \{exit_code}: \{cmd}")
      hints.push("Run the command manually to debug.")
      "Build step failed."
    }

    @cache.CacheError::CreateDir(path, cause) => {
      detail = Some(cause)
      hints.push("Check directory permissions.")
      "Failed to create cache directory " + path
    }
    @cache.CacheError::CreateTarball(path, cause) => {
      detail = Some(cause)
      hints.push("Check available disk space.")
      "Failed to create cache tarball " + path
    }
    @cache.CacheError::CacheFileNotFound(path) => {
      hints.push("Try reinstalling the package or clean the cache.")
      "Cache file not found: " + path
    }
    @cache.CacheError::ExtractTarball(path, cause) => {
      detail = Some(cause)
      hints.push("Check that the cache file is not corrupted.")
      "Failed to extract cache tarball " + path
    }
    @cache.CacheError::CleanFailed(kind) => {
      hints.push("Check file permissions for the cache directory.")
      "Failed to clean " + kind + " cache"
    }

    @installer.InstallerError::CreateDir(path, cause) => {
      detail = Some(cause)
      hints.push("Check directory permissions.")
      "Failed to create directory " + path
    }
    @installer.InstallerError::ReadManifest(path, cause) => {
      detail = Some(cause)
      hints.push("Check that the manifest file exists and is readable.")
      "Failed to read manifest " + path
    }
    @installer.InstallerError::ParseManifest(path, cause) => {
      detail = Some(cause)
      hints.push("Check JSON syntax in the manifest.")
      "Failed to parse manifest " + path
    }
    @installer.InstallerError::WriteManifest(path, cause) => {
      detail = Some(cause)
      hints.push("Check that the manifest path is writable.")
      "Failed to write manifest " + path
    }
    @installer.InstallerError::CopyFiles(path, cause) => {
      detail = Some(cause)
      hints.push("Check write permissions for the install prefix.")
      "Failed to copy files to " + path
    }
    @installer.InstallerError::TempDirCreate(cause) => {
      detail = Some(cause)
      hints.push("Check temporary directory permissions.")
      "Failed to create temporary directory."
    }
    @installer.InstallerError::PackageNotInstalled(name) => {
      hints.push("Run `moon run . list` to see installed packages.")
      "Package '\{name}' is not installed."
    }

    @repository.RepositoryError::PackageNotFound(name, version) => {
      hints.push("Check repository URLs and package versions.")
      "Package not found: \{name}@\{version}"
    }
    @repository.RepositoryError::FetchError(msg) => {
      detail = Some(msg)
      hints.push("Check repository URL and network access.")
      "Failed to fetch repository data."
    }
    @repository.RepositoryError::ParseError(msg) => {
      detail = Some(msg)
      hints.push("Repository data may be corrupted or incompatible.")
      "Failed to parse repository manifest."
    }

    @resolver.ResolverError::CircularDependency(msg) => {
      detail = Some(msg)
      hints.push("Check for circular dependencies in `moon.lib.json`.")
      "Circular dependency detected."
    }
    @resolver.ResolverError::PackageNotFound(name, version) => {
      hints.push("Check repository list and package versions.")
      "Package not found: \{name}@\{version}"
    }
    @resolver.ResolverError::ResolutionError(msg) => {
      detail = Some(msg)
      hints.push("Check repository list and network access.")
      "Failed to resolve dependencies."
    }

    @builtin.Failure(msg) => {
      detail = Some(msg)
      "Unexpected error."
    }
    _ => "Unexpected error."
  }

  if not(verbose) {
    match detail {
      Some(_) => hints.push("Run with `--verbose` for more details.")
      None => ()
    }
  }

  let details = if verbose {
    match detail {
      Some(d) => Some(d)
      None => Some(err_string)
    }
  } else {
    None
  }

  (message, hints, details)
}
