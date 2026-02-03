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
    FetchError(msg) => logger.write_string("Failed to fetch repository data: " + msg)
    ParseError(msg) => logger.write_string("Failed to parse repository manifest: " + msg)
  }
}

///|
pub(all) struct Repository {
  url : String
  is_local : Bool
} derive(Show, Eq)

///|
/// Create a new repository from a URL or local path.
/// Detects if the path is local by checking if it exists on the filesystem.
pub async fn Repository::new(url : String) -> Repository {
  let is_local = @fs.exists(url)
  { url, is_local }
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
  let base_url = if repo_url.has_suffix("/") {
    repo_url[:repo_url.length() - 1].to_string()
  } else {
    repo_url
  }
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
