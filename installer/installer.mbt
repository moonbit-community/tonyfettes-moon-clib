///| Installation management for moon-clib
///| Handles loading/saving install manifests and package installation/removal

///| Error type for installer operations
pub suberror InstallerError {
  InstallerError(String)
}

///| Get the path to the install manifest file.
///| Returns: {MOON_HOME}/lib/moon-clib.json
async fn get_manifest_path() -> String raise {
  let moon_home = @env.get_moon_home()
  moon_home + "/lib/moon-clib.json"
}

///| Check if a file exists using test -f command.
async fn file_exists(path : String) -> Bool {
  let (exit_code, _) = @process.collect_stdout("test", ["-f", path])
  exit_code == 0
}

///| Check if a directory exists using test -d command.
async fn dir_exists(path : String) -> Bool {
  let (exit_code, _) = @process.collect_stdout("test", ["-d", path])
  exit_code == 0
}

///| Ensure a directory exists, creating it if necessary.
async fn ensure_dir(path : String) -> Unit raise {
  if not(dir_exists(path)) {
    let (exit_code, output) = @process.collect_stdout("mkdir", ["-p", path])
    if exit_code != 0 {
      let msg = output.text()
      raise InstallerError("Failed to create directory \{path}: \{msg}")
    }
  }
}

///| Ensure the parent directory of a path exists.
async fn ensure_parent_dir(path : String) -> Unit raise {
  // Find the last '/' to get the parent directory
  let mut last_slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '/' {
      last_slash = i
    }
  }
  if last_slash > 0 {
    // Build the parent path
    let builder = StringBuilder::new()
    for i = 0; i < last_slash; i = i + 1 {
      builder.write_char(path[i].to_int().unsafe_to_char())
    }
    let parent = builder.to_string()
    ensure_dir(parent)
  }
}

///| Load the install manifest from disk.
///| Returns an empty manifest if the file doesn't exist.
pub async fn load_install_manifest() -> @types.InstallManifest raise {
  let manifest_path = get_manifest_path()
  if not(file_exists(manifest_path)) {
    // Return empty manifest if file doesn't exist
    return { installed: {} }
  }
  let content = try {
    @fs.read_file(manifest_path).text()
  } catch {
    err => raise InstallerError("Failed to read manifest: \{err}")
  }
  try {
    let json = @json.parse(content)
    @json.from_json(json)
  } catch {
    err => raise InstallerError("Failed to parse manifest: \{err}")
  }
}

///| Save the install manifest to disk.
pub async fn save_install_manifest(manifest : @types.InstallManifest) -> Unit raise {
  let manifest_path = get_manifest_path()
  // Ensure the parent directory exists
  ensure_parent_dir(manifest_path)
  let json = manifest.to_json()
  let text = json.stringify()
  try {
    @fs.write_file(manifest_path, text, create=0o644)
  } catch {
    err => raise InstallerError("Failed to write manifest: \{err}")
  }
}

///| Check if a package is already installed with a matching version.
pub async fn is_installed(name : String, version : String) -> Bool raise {
  let manifest = load_install_manifest()
  match manifest.installed.get(name) {
    Some(lib) => lib.version == version
    None => false
  }
}

///| Generate a simple timestamp string for installed_at.
///| Returns a date in format "YYYY-MM-DD".
async fn generate_timestamp() -> String {
  // Use date command to get current date
  let (exit_code, output) = @process.collect_stdout("date", ["+%Y-%m-%d"])
  if exit_code != 0 {
    // Fallback to a default date if date command fails
    return "2024-01-01"
  }
  output.text().trim(char_set="\n\r ").to_string()
}

///| Collect installed files from a destdir by scanning its contents.
///| Returns paths relative to the destdir.
async fn collect_installed_files(destdir : String) -> Array[String] raise {
  let files : Array[String] = []
  // Use find to list all files recursively
  let (exit_code, output) = @process.collect_stdout(
    "find",
    [destdir, "-type", "f"],
  )
  if exit_code != 0 {
    // Return empty if find fails (destdir might be empty)
    return files
  }
  let text = output.text()
  let destdir_prefix = if destdir.has_suffix("/") { destdir } else { destdir + "/" }
  for line in text.split("\n") {
    let path = line.to_string()
    if path.is_empty() {
      continue
    }
    // Remove destdir prefix to get relative path
    if path.has_prefix(destdir_prefix) {
      let relative = path[destdir_prefix.length():].to_string()
      if not(relative.is_empty()) {
        files.push(relative)
      }
    }
  }
  files
}

///| Copy files from destdir to prefix.
async fn copy_files_to_prefix(destdir : String, prefix : String) -> Unit raise {
  // Use cp -r to recursively copy all contents
  // First ensure prefix exists
  ensure_dir(prefix)
  // Copy contents of destdir to prefix
  // The destdir contains files like lib/..., include/..., etc.
  let (exit_code, output) = @process.collect_stdout(
    "sh",
    ["-c", "cp -r '\{destdir}'/* '\{prefix}'/"],
  )
  if exit_code != 0 {
    let msg = output.text()
    // Check if it's just an empty destdir (no files to copy)
    let files = collect_installed_files(destdir)
    if files.is_empty() {
      // No files to copy, not an error
      return
    }
    raise InstallerError("Failed to copy files to prefix: \{msg}")
  }
}

///| Create a temporary directory for destdir.
async fn create_temp_destdir() -> String raise {
  let (exit_code, output) = @process.collect_stdout("mktemp", ["-d"])
  if exit_code != 0 {
    raise InstallerError("Failed to create temporary directory")
  }
  output.text().trim(char_set="\n\r ").to_string()
}

///| Remove a temporary directory.
async fn remove_temp_dir(path : String) -> Unit {
  let _ = @process.collect_stdout("rm", ["-rf", path])
  ()
}

///| Build a package from source.
///| Returns the list of installed files.
async fn build_from_source(
  name : String,
  version : String,
  manifest : @types.PackageManifest,
  repo : @repository.Repository,
  prefix : String
) -> Array[String] raise {
  // Create srcdir
  let src_cache_dir = @cache.get_src_cache_dir()
  let srcdir = src_cache_dir + "/" + name + "-" + version
  ensure_dir(srcdir)
  // Create temp destdir
  let destdir = create_temp_destdir()
  let installed_files : Array[String] = try {
    // Fetch sources
    @source.fetch_sources(manifest.source, srcdir, repo, name, version)
    // Build context
    let jobs = @env.get_jobs()
    let os = @env.get_os()
    let arch = @env.get_arch()
    let ctx : @builder.BuildContext = { prefix, destdir, srcdir, jobs, os, arch }
    // Execute build
    @builder.execute_build(manifest.build, ctx)
    // Collect installed files from destdir
    let files = collect_installed_files(destdir)
    // Save to cache
    @cache.save_to_cache(name, version, destdir)
    // Copy files to prefix
    copy_files_to_prefix(destdir, prefix)
    files
  } catch {
    err => {
      // Clean up temp directory on error
      remove_temp_dir(destdir)
      raise err
    }
  }
  // Clean up temp directory
  remove_temp_dir(destdir)
  installed_files
}

///| Install a package.
///|
///| Workflow:
///| 1. Check if already installed with matching version (skip if not force)
///| 2. Check cache for tarball
///| 3. If cached: extract to $MOON_HOME
///| 4. If not cached: fetch sources, build, save to cache, copy to $MOON_HOME
///| 5. Update install manifest with file list
pub async fn install_package(
  name : String,
  version : String,
  manifest : @types.PackageManifest,
  repo : @repository.Repository,
  force~ : Bool
) -> Unit raise {
  // Step 1: Check if already installed
  if not(force) && is_installed(name, version) {
    // Already installed with matching version, skip
    return
  }
  let prefix = @env.get_moon_home()
  // Step 2 & 3 & 4: Get installed files from cache or build
  let installed_files = if @cache.is_cached(name, version) {
    // Extract from cache
    @cache.extract_from_cache(name, version, prefix)
  } else {
    // Build from source
    build_from_source(name, version, manifest, repo, prefix)
  }
  // Step 5: Update install manifest
  let install_manifest = load_install_manifest()
  let timestamp = generate_timestamp()
  let installed_lib : @types.InstalledLibrary = {
    version,
    installed_at: timestamp,
    files: installed_files,
  }
  install_manifest.installed[name] = installed_lib
  save_install_manifest(install_manifest)
}

///| Remove an installed package.
///| Deletes all files recorded in the manifest and updates the manifest.
pub async fn remove_package(name : String) -> Unit raise {
  let manifest = load_install_manifest()
  match manifest.installed.get(name) {
    None => raise InstallerError("Package '\{name}' is not installed")
    Some(lib) => {
      let prefix = @env.get_moon_home()
      // Delete all installed files
      for file in lib.files {
        let file_path = prefix + "/" + file
        if file_exists(file_path) {
          let (exit_code, _) = @process.collect_stdout("rm", ["-f", file_path])
          if exit_code != 0 {
            // Log warning but continue
            ()
          }
        }
      }
      // Remove from manifest
      manifest.installed.remove(name)
      save_install_manifest(manifest)
    }
  }
}
