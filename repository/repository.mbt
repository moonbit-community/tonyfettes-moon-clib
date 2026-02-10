///| Package repository operations for moon-clib

///|
/// Error type for repository operations
pub suberror RepositoryError {
  PackageNotFound(String, String)
  FetchError(String)
  ParseError(String)
}

///|
/// Human-readable error output
pub impl Show for RepositoryError with output(
  self : RepositoryError,
  logger : &@builtin.Logger,
) -> Unit {
  match self {
    PackageNotFound(name, version) =>
      logger.write_string("Package not found: \{name}@\{version}")
    FetchError(msg) =>
      logger.write_string("Failed to fetch repository data: " + msg)
    ParseError(msg) =>
      logger.write_string("Failed to parse repository manifest: " + msg)
  }
}

///|
pub(all) struct Repository {
  url : String
  is_local : Bool
} derive(Show, Eq)

///|
/// Create a new repository from a URL or local path.
/// Detects if the path is local by checking if it exists and is a directory.
pub async fn Repository::new(url : String) -> Repository {
  let is_local = if @fs.exists(url) { is_directory(url) } else { false }
  { url, is_local }
}

///|
/// Validate a configured repository input.
///
/// Rules:
/// - existing directory path => valid local repository
/// - otherwise => must be a valid git remote (`git ls-remote`)
pub async fn validate_repository(url : String) -> Unit {
  if @fs.exists(url) {
    if not(is_directory(url)) {
      raise FetchError("Repository path is not a directory: \{url}")
    }
    return
  }
  let (exit_code, message) = run_git(["ls-remote", url])
  if exit_code != 0 {
    let detail = with_detail("Invalid git repository '\{url}'", message)
    raise FetchError(detail)
  }
}

///|
/// Resolve a configured repository to a local path.
///
/// Local repositories are returned as-is.
/// Git remotes are cloned/fetched into a local mirror cache.
pub async fn resolve_repository(url : String) -> Repository {
  if @fs.exists(url) {
    if not(is_directory(url)) {
      raise FetchError("Repository path is not a directory: \{url}")
    }
    return { url, is_local: true }
  }
  let mirror_path = sync_git_repository(url)
  { url: mirror_path, is_local: true }
}

///|
/// Update/sync a repository and return its resolved local form.
pub async fn update_repository(url : String) -> Repository {
  resolve_repository(url)
}

///|
/// Fetch the manifest.json for a package from this repository.
/// For local repos: reads from {repo_path}/{name}/{version}/manifest.json
/// For remote repos: HTTP GET {repo_url}/{name}/{version}/manifest.json
pub async fn fetch_manifest(
  repo : Repository,
  name : String,
  version : String,
) -> @types.PackageManifest {
  let manifest_path = "\{name}/\{version}/manifest.json"
  let content = if repo.is_local {
    fetch_local_file(repo.url, manifest_path)
  } else {
    fetch_remote_file(repo.url, manifest_path)
  }
  parse_manifest(content)
}

///|
/// Fetch a file from the package directory in this repository.
/// Used for fetching patches and other files stored alongside the manifest.
/// For local repos: reads from {repo_path}/{name}/{version}/{path}
/// For remote repos: HTTP GET {repo_url}/{name}/{version}/{path}
pub async fn fetch_package_file(
  repo : Repository,
  name : String,
  version : String,
  path : String,
) -> Bytes {
  let file_path = "\{name}/\{version}/\{path}"
  if repo.is_local {
    fetch_local_file(repo.url, file_path)
  } else {
    fetch_remote_file(repo.url, file_path)
  }
}

///|
/// Search repositories in order and return the first matching package.
/// Returns the repository and manifest for the found package.
pub async fn find_package(
  repos : Array[Repository],
  name : String,
  version : String,
) -> (Repository, @types.PackageManifest) {
  for repo in repos {
    try {
      let manifest = fetch_manifest(repo, name, version)
      return (repo, manifest)
    } catch {
      _ => continue
    }
  }
  raise PackageNotFound(name, version)
}

///|
/// Fetch a file from a local repository.
async fn fetch_local_file(repo_path : String, file_path : String) -> Bytes {
  let full_path = "\{repo_path}/\{file_path}"
  try {
    let data = @fs.read_file(full_path)
    data.binary()
  } catch {
    err => raise FetchError("Failed to read local file \{full_path}: \{err}")
  }
}

///|
/// Fetch a file from a remote repository via HTTP.
async fn fetch_remote_file(repo_url : String, file_path : String) -> Bytes {
  // Ensure URL doesn't have trailing slash
  let base_url = strip_trailing_slash(repo_url)
  let url = "\{base_url}/\{file_path}"
  try {
    let (response, body) = @http.get(url)
    if response.code < 200 || response.code >= 300 {
      raise FetchError("HTTP \{response.code}: \{response.reason} for \{url}")
    }
    body.binary()
  } catch {
    FetchError(_) as err => raise err
    err => raise FetchError("Failed to fetch \{url}: \{err}")
  }
}

///|
/// Parse a manifest.json file content into a PackageManifest.
fn parse_manifest(content : Bytes) -> @types.PackageManifest raise {
  let text = @utf8.decode(content) catch {
    _ => raise ParseError("Invalid UTF-8 in manifest")
  }
  try {
    let json = @json.parse(text)
    @json.from_json(json)
  } catch {
    err => raise ParseError("Failed to parse manifest: \{err}")
  }
}

///|
/// Check whether a path is a directory.
async fn is_directory(path : String) -> Bool {
  let (exit_code, _) = @process.collect_stdout("test", ["-d", path])
  exit_code == 0
}

///|
/// Run a git command and return (exit_code, trimmed_stderr_stdout).
async fn run_git(args : FixedArray[String]) -> (Int, String) {
  let (exit_code, output) = @process.collect_stdout("git", args[:])
  let message = output.text().trim(char_set="\n\r ").to_string()
  (exit_code, message)
}

///|
/// Ensure a directory exists.
async fn ensure_dir(path : String) -> Unit {
  if @fs.exists(path) {
    if not(is_directory(path)) {
      raise FetchError("Path exists but is not a directory: \{path}")
    }
    return
  }
  @fs.mkdir(path, permission=0o755, recursive=true) catch {
    err => raise FetchError("Failed to create directory \{path}: \{err}")
  }
}

///|
/// Build a deterministic cache key for a repository URL.
fn cache_key_for_repository(url : String) -> String {
  let hash_text = "\{url.hash()}".replace_all(old="-", new="_")
  "\{url.length()}-\{hash_text}"
}

///|
/// Return the mirror root directory under the cache.
async fn mirror_root_dir() -> String {
  @env.get_cache_dir() + "/repos"
}

///|
/// Clone or update a git repository into the local cache.
async fn sync_git_repository(url : String) -> String {
  let root = mirror_root_dir()
  ensure_dir(root)
  let mirror_path = "\{root}/\{cache_key_for_repository(url)}"
  if not(@fs.exists(mirror_path)) {
    let (exit_code, message) = run_git([
      "clone", "--depth", "1", url, mirror_path,
    ])
    if exit_code != 0 {
      let detail = with_detail("Failed to clone repository '\{url}'", message)
      raise FetchError(detail)
    }
    return mirror_path
  }
  if not(is_directory(mirror_path)) {
    raise FetchError(
      "Repository mirror path is not a directory: \{mirror_path}",
    )
  }
  let (fetch_code, fetch_message) = run_git([
    "-C", mirror_path, "fetch", "--depth", "1", "origin",
  ])
  if fetch_code != 0 {
    let detail = with_detail(
      "Failed to fetch repository '\{url}'",
      fetch_message,
    )
    raise FetchError(detail)
  }
  let (reset_code, reset_message) = run_git([
    "-C", mirror_path, "reset", "--hard", "FETCH_HEAD",
  ])
  if reset_code != 0 {
    let detail = with_detail(
      "Failed to reset repository '\{url}' to FETCH_HEAD",
      reset_message,
    )
    raise FetchError(detail)
  }
  mirror_path
}

///|
/// Strip a trailing slash from a URL/path if present.
fn strip_trailing_slash(text : String) -> String {
  if not(text.has_suffix("/")) {
    return text
  }
  if text.length() <= 1 {
    return text
  }
  let builder = StringBuilder::new()
  for i = 0; i < text.length() - 1; i = i + 1 {
    builder.write_char(text[i].to_int().unsafe_to_char())
  }
  builder.to_string()
}

///|
/// Attach optional command output detail to an error prefix.
fn with_detail(prefix : String, detail : String) -> String {
  if detail.is_empty() {
    prefix
  } else {
    "\{prefix}: \{detail}"
  }
}
