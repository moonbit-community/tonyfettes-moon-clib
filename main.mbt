///| Main entry point for moon-clib CLI application

///| Application version
let version : String = "0.1.0"

///| Run the install command
async fn run_install(force : Bool) -> Unit raise {
  let project = @config.load_project_deps()
  let config = @config.load_config()
  let repos : Array[@repository.Repository] = []
  for url in config.repositories {
    repos.push(@repository.Repository::new(url))
  }
  let packages = @resolver.resolve_dependencies(project.dependencies, repos)
  for pkg in packages {
    println("Installing \{pkg.name}@\{pkg.version}...")
    @installer.install_package(
      pkg.name,
      pkg.version,
      pkg.manifest,
      pkg.repository,
      force~,
    )
  }
  println("Done!")
}

///| Run the list command
async fn run_list() -> Unit raise {
  let manifest = @installer.load_install_manifest()
  if manifest.installed.is_empty() {
    println("No libraries installed.")
  } else {
    for name, lib in manifest.installed {
      println("\{name}@\{lib.version} (installed: \{lib.installed_at})")
    }
  }
}

///| Run the info command
async fn run_info(name : String) -> Unit raise {
  let manifest = @installer.load_install_manifest()
  match manifest.installed.get(name) {
    None => println("Library '\{name}' is not installed.")
    Some(lib) => {
      println("Name: \{name}")
      println("Version: \{lib.version}")
      println("Installed: \{lib.installed_at}")
      println("Files:")
      for file in lib.files {
        println("  \{file}")
      }
    }
  }
}

///| Run the remove command
async fn run_remove(name : String) -> Unit raise {
  println("Removing \{name}...")
  @installer.remove_package(name)
  println("Done!")
}

///| Run the repo list command
async fn run_repo_list() -> Unit raise {
  let config = @config.load_config()
  if config.repositories.is_empty() {
    println("No repositories configured.")
  } else {
    println("Configured repositories:")
    for url in config.repositories {
      println("  \{url}")
    }
  }
}

///| Run the repo add command
async fn run_repo_add(url : String) -> Unit raise {
  let config = @config.load_config()
  // Check if already exists
  for existing in config.repositories {
    if existing == url {
      println("Repository '\{url}' is already configured.")
      return
    }
  }
  config.repositories.push(url)
  @config.save_config(config)
  println("Added repository: \{url}")
}

///| Run the repo remove command
async fn run_repo_remove(url : String) -> Unit raise {
  let config = @config.load_config()
  let new_repos : Array[String] = []
  let mut found = false
  for existing in config.repositories {
    if existing == url {
      found = true
    } else {
      new_repos.push(existing)
    }
  }
  if not(found) {
    println("Repository '\{url}' is not configured.")
    return
  }
  let new_config : @types.Config = { repositories: new_repos }
  @config.save_config(new_config)
  println("Removed repository: \{url}")
}

///| Run the repo update command (placeholder)
fn run_repo_update() -> Unit {
  println("Repository update is not yet implemented.")
  println("This will sync repository indexes in the future.")
}

///| Run the cache list command
async fn run_cache_list() -> Unit raise {
  let cached = @cache.list_cached()
  if cached.is_empty() {
    println("No packages cached.")
  } else {
    println("Cached packages:")
    for item in cached {
      let (name, ver) = item
      println("  \{name}@\{ver}")
    }
  }
}

///| Run the cache clean command
async fn run_cache_clean() -> Unit raise {
  println("Cleaning cache...")
  @cache.clean_cache()
  println("Cache cleaned.")
}

///| Print help message
fn print_help() -> Unit {
  println("moon-clib - C library manager for MoonBit")
  println("")
  println("USAGE:")
  println("    moon-clib [OPTIONS] [COMMAND]")
  println("")
  println("COMMANDS:")
  println("    (default)           Install all libraries from moon.lib.json")
  println("    list                List installed libraries")
  println("    info <name>         Show info about a library")
  println("    remove <name>       Remove an installed library")
  println("")
  println("    repo list           List configured repositories")
  println("    repo add <url>      Add a repository")
  println("    repo remove <url>   Remove a repository")
  println("    repo update         Update repository indexes (placeholder)")
  println("")
  println("    cache list          List cached packages")
  println("    cache clean         Remove all cached packages")
  println("")
  println("OPTIONS:")
  println("    --force             Reinstall even if already installed")
  println("    --help, -h          Show this help message")
  println("    --version, -v       Show version")
}

///| Print version
fn print_version() -> Unit {
  println("moon-clib \{version}")
}

///| Main entry point
async fn main {
  try {
    let args = @env.args()
    // Skip the program name (first argument)
    let cmd_args : Array[String] = []
    for i = 1; i < args.length(); i = i + 1 {
      cmd_args.push(args[i])
    }
    let cmd = @cli.parse_args(cmd_args)
    match cmd {
      @cli.Command::Install(force~) => run_install(force)
      @cli.Command::List => run_list()
      @cli.Command::Info(name~) => run_info(name)
      @cli.Command::Remove(name~) => run_remove(name)
      @cli.Command::RepoList => run_repo_list()
      @cli.Command::RepoAdd(url~) => run_repo_add(url)
      @cli.Command::RepoRemove(url~) => run_repo_remove(url)
      @cli.Command::RepoUpdate => run_repo_update()
      @cli.Command::CacheList => run_cache_list()
      @cli.Command::CacheClean => run_cache_clean()
      @cli.Command::Help => print_help()
      @cli.Command::Version => print_version()
    }
  } catch {
    err => println("error: \{err}")
  }
}
