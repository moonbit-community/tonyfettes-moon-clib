///|
/// Build step conditions based on OS and architecture
pub(all) struct Condition {
  os : String?
  arch : String?
} derive(Show, Eq)

///|
pub impl ToJson for Condition with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  match self.os {
    Some(v) => obj["os"] = v.to_json()
    None => ()
  }
  match self.arch {
    Some(v) => obj["arch"] = v.to_json()
    None => ()
  }
  Json::object(obj)
}

///|
pub impl @json.FromJson for Condition with from_json(json, path) -> Condition raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for Condition"))
  }
  let os : String? = match obj.get("os") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let arch : String? = match obj.get("arch") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  { os, arch }
}

///|
/// A build step with command, optional condition, environment, and working directory
pub(all) struct BuildStep {
  run : Array[String]
  when : Condition?
  env : Map[String, String]?
  cwd : String?
} derive(Show, Eq)

///|
pub impl ToJson for BuildStep with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  obj["run"] = self.run.to_json()
  match self.when {
    Some(v) => obj["when"] = v.to_json()
    None => ()
  }
  match self.env {
    Some(v) => obj["env"] = v.to_json()
    None => ()
  }
  match self.cwd {
    Some(v) => obj["cwd"] = v.to_json()
    None => ()
  }
  Json::object(obj)
}

///|
pub impl @json.FromJson for BuildStep with from_json(json, path) -> BuildStep raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for BuildStep"))
  }
  let run : Array[String] = match obj.get("run") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: run"))
  }
  let when : Condition? = match obj.get("when") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let env : Map[String, String]? = match obj.get("env") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let cwd : String? = match obj.get("cwd") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  { run, when, env, cwd }
}

///|
/// Tarball source - download and extract archive
pub(all) struct TarballSource {
  url : String
  sha256 : String?
  strip_components : Int?
  dest : String?
} derive(Show, Eq)

///|
pub impl ToJson for TarballSource with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  obj["url"] = self.url.to_json()
  match self.sha256 {
    Some(v) => obj["sha256"] = v.to_json()
    None => ()
  }
  match self.strip_components {
    Some(v) => obj["strip_components"] = v.to_json()
    None => ()
  }
  match self.dest {
    Some(v) => obj["dest"] = v.to_json()
    None => ()
  }
  Json::object(obj)
}

///|
pub impl @json.FromJson for TarballSource with from_json(json, path) -> TarballSource raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for TarballSource"))
  }
  let url : String = match obj.get("url") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: url"))
  }
  let sha256 : String? = match obj.get("sha256") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let strip_components : Int? = match obj.get("strip_components") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let dest : String? = match obj.get("dest") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  { url, sha256, strip_components, dest }
}

///|
/// Git source - clone repository
pub(all) struct GitSource {
  url : String
  ref_ : String
  shallow : Bool?
  dest : String?
} derive(Show, Eq)

///|
pub impl ToJson for GitSource with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  obj["url"] = self.url.to_json()
  obj["ref"] = self.ref_.to_json()
  match self.shallow {
    Some(v) => obj["shallow"] = v.to_json()
    None => ()
  }
  match self.dest {
    Some(v) => obj["dest"] = v.to_json()
    None => ()
  }
  Json::object(obj)
}

///|
pub impl @json.FromJson for GitSource with from_json(json, path) -> GitSource raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for GitSource"))
  }
  let url : String = match obj.get("url") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: url"))
  }
  let ref_ : String = match obj.get("ref") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: ref"))
  }
  let shallow : Bool? = match obj.get("shallow") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let dest : String? = match obj.get("dest") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  { url, ref_, shallow, dest }
}

///|
/// File source - download single file or copy from package dir
pub(all) struct FileSource {
  url : String?
  path : String?
  sha256 : String?
  dest : String?
} derive(Show, Eq)

///|
pub impl ToJson for FileSource with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  match self.url {
    Some(v) => obj["url"] = v.to_json()
    None => ()
  }
  match self.path {
    Some(v) => obj["path"] = v.to_json()
    None => ()
  }
  match self.sha256 {
    Some(v) => obj["sha256"] = v.to_json()
    None => ()
  }
  match self.dest {
    Some(v) => obj["dest"] = v.to_json()
    None => ()
  }
  Json::object(obj)
}

///|
pub impl @json.FromJson for FileSource with from_json(json, path) -> FileSource raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for FileSource"))
  }
  let url : String? = match obj.get("url") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let file_path : String? = match obj.get("path") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let sha256 : String? = match obj.get("sha256") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let dest : String? = match obj.get("dest") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  { url, path: file_path, sha256, dest }
}

///|
/// Local source - reference local directory
pub(all) struct LocalSource {
  path : String
  dest : String?
} derive(Show, Eq)

///|
pub impl ToJson for LocalSource with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  obj["path"] = self.path.to_json()
  match self.dest {
    Some(v) => obj["dest"] = v.to_json()
    None => ()
  }
  Json::object(obj)
}

///|
pub impl @json.FromJson for LocalSource with from_json(json, path) -> LocalSource raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for LocalSource"))
  }
  let local_path : String = match obj.get("path") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: path"))
  }
  let dest : String? = match obj.get("dest") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  { path: local_path, dest }
}

///|
/// Source specification - discriminated by "type" field in JSON
pub(all) enum Source {
  Tarball(TarballSource)
  Git(GitSource)
  File(FileSource)
  Local(LocalSource)
} derive(Show, Eq)

///|
pub impl ToJson for Source with to_json(self) -> Json {
  match self {
    Tarball(src) => {
      guard src.to_json() is Object(obj) else {
        abort("TarballSource.to_json should return Object")
      }
      obj["type"] = Json::string("tarball")
      Json::object(obj)
    }
    Git(src) => {
      guard src.to_json() is Object(obj) else {
        abort("GitSource.to_json should return Object")
      }
      obj["type"] = Json::string("git")
      Json::object(obj)
    }
    File(src) => {
      guard src.to_json() is Object(obj) else {
        abort("FileSource.to_json should return Object")
      }
      obj["type"] = Json::string("file")
      Json::object(obj)
    }
    Local(src) => {
      guard src.to_json() is Object(obj) else {
        abort("LocalSource.to_json should return Object")
      }
      obj["type"] = Json::string("local")
      Json::object(obj)
    }
  }
}

///|
pub impl @json.FromJson for Source with from_json(json, path) -> Source raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for Source"))
  }
  let type_field = match obj.get("type") {
    Some(String(t)) => t
    Some(_) =>
      raise @json.JsonDecodeError((path, "type field must be a string"))
    None => raise @json.JsonDecodeError((path, "missing type field in Source"))
  }
  match type_field {
    "tarball" => Tarball(@json.FromJson::from_json(json, path))
    "git" => Git(@json.FromJson::from_json(json, path))
    "file" => {
      let src : FileSource = @json.FromJson::from_json(json, path)
      // Validate XOR constraint: must have url OR path, not both, not neither
      match (src.url, src.path) {
        (None, None) =>
          raise @json.JsonDecodeError(
            (path, "FileSource must have either url or path"),
          )
        (Some(_), Some(_)) =>
          raise @json.JsonDecodeError(
            (path, "FileSource cannot have both url and path"),
          )
        _ => File(src)
      }
    }
    "local" => Local(@json.FromJson::from_json(json, path))
    _ =>
      raise @json.JsonDecodeError((path, "unknown source type: \{type_field}"))
  }
}

///|
/// Package manifest.json in the repository
pub(all) struct PackageManifest {
  description : String?
  author : String?
  license : String?
  homepage : String?
  source : Array[Source]
  dependencies : Map[String, String]?
  build : Array[BuildStep]
} derive(Show, Eq)

///|
pub impl ToJson for PackageManifest with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  match self.description {
    Some(v) => obj["description"] = v.to_json()
    None => ()
  }
  match self.author {
    Some(v) => obj["author"] = v.to_json()
    None => ()
  }
  match self.license {
    Some(v) => obj["license"] = v.to_json()
    None => ()
  }
  match self.homepage {
    Some(v) => obj["homepage"] = v.to_json()
    None => ()
  }
  obj["source"] = self.source.to_json()
  match self.dependencies {
    Some(v) => obj["dependencies"] = v.to_json()
    None => ()
  }
  obj["build"] = self.build.to_json()
  Json::object(obj)
}

///|
pub impl @json.FromJson for PackageManifest with from_json(json, path) -> PackageManifest raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for PackageManifest"))
  }
  let description : String? = match obj.get("description") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let author : String? = match obj.get("author") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let license : String? = match obj.get("license") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let homepage : String? = match obj.get("homepage") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let source : Array[Source] = match obj.get("source") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: source"))
  }
  let dependencies : Map[String, String]? = match obj.get("dependencies") {
    Some(v) => Some(@json.FromJson::from_json(v, path))
    None => None
  }
  let build : Array[BuildStep] = match obj.get("build") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: build"))
  }
  { description, author, license, homepage, source, dependencies, build }
}

///|
/// Project dependencies from moon.lib.json
pub(all) struct ProjectDependencies {
  dependencies : Map[String, String]
} derive(Show, Eq)

///|
pub impl ToJson for ProjectDependencies with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  obj["dependencies"] = self.dependencies.to_json()
  Json::object(obj)
}

///|
pub impl @json.FromJson for ProjectDependencies with from_json(json, path) -> ProjectDependencies raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError(
      (path, "expected object for ProjectDependencies"),
    )
  }
  let dependencies : Map[String, String] = match obj.get("dependencies") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: dependencies"))
  }
  { dependencies, }
}

///|
/// Repository configuration
pub(all) struct Config {
  repositories : Array[String]
} derive(Show, Eq)

///|
pub impl ToJson for Config with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  obj["repositories"] = self.repositories.to_json()
  Json::object(obj)
}

///|
pub impl @json.FromJson for Config with from_json(json, path) -> Config raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for Config"))
  }
  let repositories : Array[String] = match obj.get("repositories") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: repositories"))
  }
  { repositories, }
}

///|
/// Information about an installed library
pub(all) struct InstalledLibrary {
  version : String
  installed_at : String
  files : Array[String]
} derive(Show, Eq)

///|
pub impl ToJson for InstalledLibrary with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  obj["version"] = self.version.to_json()
  obj["installed_at"] = self.installed_at.to_json()
  obj["files"] = self.files.to_json()
  Json::object(obj)
}

///|
pub impl @json.FromJson for InstalledLibrary with from_json(json, path) -> InstalledLibrary raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for InstalledLibrary"))
  }
  let version : String = match obj.get("version") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: version"))
  }
  let installed_at : String = match obj.get("installed_at") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: installed_at"))
  }
  let files : Array[String] = match obj.get("files") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: files"))
  }
  { version, installed_at, files }
}

///|
/// Install manifest tracking installed libraries
pub(all) struct InstallManifest {
  installed : Map[String, InstalledLibrary]
} derive(Show, Eq)

///|
pub impl ToJson for InstallManifest with to_json(self) -> Json {
  let obj : Map[String, Json] = {}
  obj["installed"] = self.installed.to_json()
  Json::object(obj)
}

///|
pub impl @json.FromJson for InstallManifest with from_json(json, path) -> InstallManifest raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object for InstallManifest"))
  }
  let installed : Map[String, InstalledLibrary] = match obj.get("installed") {
    Some(v) => @json.FromJson::from_json(v, path)
    None => raise @json.JsonDecodeError((path, "missing field: installed"))
  }
  { installed, }
}
