///| Source fetching module for moon-clib

///| Handles fetching sources from tarball, git, file, and local paths

///|
/// Error type for source fetching operations
pub suberror SourceError {
  FetchError(String)
  InvalidSource(String)
}

///| Derive the default destination directory name from a URL.

///|
/// Extracts the last path component and removes common archive extensions.
pub fn derive_dest_from_url(url : String) -> String {
  // Find the last '/' to get the filename
  let mut last_slash = -1
  for i = 0; i < url.length(); i = i + 1 {
    if url[i] == '/' {
      last_slash = i
    }
  }
  let filename = if last_slash >= 0 {
    // There's a slash, take everything after it
    if last_slash + 1 < url.length() {
      let builder = StringBuilder::new()
      for i = last_slash + 1; i < url.length(); i = i + 1 {
        builder.write_char(url[i].to_int().unsafe_to_char())
      }
      builder.to_string()
    } else {
      // URL ends with slash, return empty string
      ""
    }
  } else {
    // No slash, use the entire URL
    url
  }
  // Remove common archive extensions
  strip_extensions(filename)
}

///|
/// Derive the default destination directory name from a local path.
pub fn derive_dest_from_path(path : String) -> String {
  // Find the last '/' to get the directory/file name
  let mut last_slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '/' {
      last_slash = i
    }
  }
  if last_slash >= 0 {
    // There's a slash, take everything after it
    if last_slash + 1 < path.length() {
      let builder = StringBuilder::new()
      for i = last_slash + 1; i < path.length(); i = i + 1 {
        builder.write_char(path[i].to_int().unsafe_to_char())
      }
      builder.to_string()
    } else {
      // Path ends with slash, return empty string
      ""
    }
  } else {
    // No slash, use the entire path
    path
  }
}

///|
/// Strip common archive/compression extensions from a filename.
pub fn strip_extensions(filename : String) -> String {
  let extensions = [
    ".tar.gz", ".tar.xz", ".tar.bz2", ".tgz", ".txz", ".tbz2", ".zip", ".tar", ".gz",
    ".xz", ".bz2", ".git",
  ]
  let mut result = filename
  for ext in extensions {
    if result.has_suffix(ext) {
      // Build the substring without the extension
      let new_len = result.length() - ext.length()
      let builder = StringBuilder::new()
      for i = 0; i < new_len; i = i + 1 {
        builder.write_char(result[i].to_int().unsafe_to_char())
      }
      result = builder.to_string()
      break
    }
  }
  result
}

///| Fetch all sources in the given array.

///|
/// Dispatches to the appropriate fetch function based on source type.
pub async fn fetch_sources(
  sources : Array[@types.Source],
  srcdir : String,
  repo : @repository.Repository,
  name : String,
  version : String,
) -> Unit {
  for source in sources {
    match source {
      @types.Source::Tarball(src) => {
        let dest = match src.dest {
          Some(d) => srcdir + "/" + d
          None => srcdir + "/" + derive_dest_from_url(src.url)
        }
        fetch_tarball(src, dest)
      }
      @types.Source::Git(src) => {
        let dest = match src.dest {
          Some(d) => srcdir + "/" + d
          None => srcdir + "/" + derive_dest_from_url(src.url)
        }
        fetch_git(src, dest)
      }
      @types.Source::File(src) => {
        let dest = match src.dest {
          Some(d) => srcdir + "/" + d
          None =>
            match (src.url, src.path) {
              (Some(url), _) => srcdir + "/" + derive_dest_from_url(url)
              (_, Some(path)) => srcdir + "/" + derive_dest_from_path(path)
              (None, None) =>
                raise InvalidSource("FileSource must have either url or path")
            }
        }
        fetch_file(src, dest, repo, name, version)
      }
      @types.Source::Local(src) => {
        let dest = match src.dest {
          Some(d) => srcdir + "/" + d
          None => srcdir + "/" + derive_dest_from_path(src.path)
        }
        fetch_local(src, dest)
      }
    }
  }
}

///| Fetch a tarball source: download and extract archive.

///|
/// Uses: curl -fsSL {url} | tar -xz --strip-components={n} -C {dest}
pub async fn fetch_tarball(src : @types.TarballSource, dest : String) -> Unit {
  // Ensure destination directory exists
  if not(@fs.exists(dest)) {
    @fs.mkdir(dest, permission=0o755, recursive=true) catch {
      _ => () // Directory may already exist
    }
  }
  let strip = match src.strip_components {
    Some(n) => n
    None => 0
  }
  // Build the shell command for piping curl to tar
  let cmd = "sh"
  let shell_cmd = "curl -fsSL '\{src.url}' | tar -xz --strip-components=\{strip} -C '\{dest}'"
  let args : FixedArray[String] = ["-c", shell_cmd]
  let exit_code = @process.run(cmd, args[:])
  if exit_code != 0 {
    raise FetchError(
      "Failed to fetch tarball from \{src.url}: exit code \{exit_code}",
    )
  }
}

///| Fetch a git source: clone repository.

///| If shallow is true (or None, default), uses: git clone --depth 1 --branch {ref} {url} {dest}

///|
/// If shallow is false, uses: git clone --branch {ref} {url} {dest}
pub async fn fetch_git(src : @types.GitSource, dest : String) -> Unit {
  let shallow = match src.shallow {
    Some(s) => s
    None => true
  }
  let args : Array[String] = ["clone"]
  if shallow {
    args.push("--depth")
    args.push("1")
  }
  args.push("--branch")
  args.push(src.ref_)
  args.push(src.url)
  args.push(dest)
  let fixed_args : FixedArray[String] = FixedArray::makei(args.length(), fn(i) {
    args[i]
  })
  let exit_code = @process.run("git", fixed_args[:])
  if exit_code != 0 {
    raise FetchError(
      "Failed to clone git repository \{src.url}: exit code \{exit_code}",
    )
  }
}

///| Fetch a file source: download single file or copy from package dir.

///| With url: curl -fsSL -o {dest} {url}

///|
/// With path: use @repository.fetch_package_file() to get bytes, write to dest
pub async fn fetch_file(
  src : @types.FileSource,
  dest : String,
  repo : @repository.Repository,
  name : String,
  version : String,
) -> Unit {
  // Ensure parent directory exists
  ensure_parent_dir(dest)
  match (src.url, src.path) {
    (Some(url), _) => {
      // Fetch from URL using curl
      let cmd = "curl"
      let args : FixedArray[String] = ["-fsSL", "-o", dest, url]
      let exit_code = @process.run(cmd, args[:])
      if exit_code != 0 {
        raise FetchError(
          "Failed to fetch file from \{url}: exit code \{exit_code}",
        )
      }
    }
    (_, Some(path)) => {
      // Fetch from package repository
      let bytes = @repository.fetch_package_file(repo, name, version, path) catch {
        err => raise FetchError("Failed to fetch package file \{path}: \{err}")
      }
      @fs.write_file(dest, bytes, create=0o644) catch {
        err => raise FetchError("Failed to write file \{dest}: \{err}")
      }
    }
    (None, None) =>
      raise InvalidSource("FileSource must have either url or path")
  }
}

///| Fetch a local source: copy directory recursively.

///|
/// Uses: cp -r {path} {dest}
pub async fn fetch_local(src : @types.LocalSource, dest : String) -> Unit {
  // Ensure parent directory exists
  ensure_parent_dir(dest)
  let cmd = "cp"
  let args : FixedArray[String] = ["-r", src.path, dest]
  let exit_code = @process.run(cmd, args[:])
  if exit_code != 0 {
    raise FetchError(
      "Failed to copy local source from \{src.path}: exit code \{exit_code}",
    )
  }
}

///|
/// Ensure the parent directory of a path exists.
async fn ensure_parent_dir(path : String) -> Unit {
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
    if not(@fs.exists(parent)) {
      @fs.mkdir(parent, permission=0o755, recursive=true) catch {
        _ => () // Directory may already exist
      }
    }
  }
}
