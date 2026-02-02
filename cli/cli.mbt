///|
/// CLI commands for moon-clib
pub(all) enum Command {
  Install(force~ : Bool)
  List
  Info(name~ : String)
  Remove(name~ : String)
  RepoList
  RepoAdd(url~ : String)
  RepoRemove(url~ : String)
  RepoUpdate
  CacheList
  CacheClean
  Help
  Version
} derive(Show, Eq)

///|
/// Errors that can occur during argument parsing
pub suberror ParseError {
  UnknownCommand(String)
  MissingArgument(String)
  UnknownFlag(String)
}

///|
/// Parse command-line arguments into a Command
pub fn parse_args(args : Array[String]) -> Command raise ParseError {
  // Separate flags from positional arguments
  let flags : Array[String] = []
  let positional : Array[String] = []
  for arg in args {
    if arg.has_prefix("-") {
      flags.push(arg)
    } else {
      positional.push(arg)
    }
  }
  // Check for help/version flags first (they take precedence)
  for flag in flags {
    match flag {
      "--help" | "-h" => return Help
      "--version" | "-v" => return Version
      _ => ()
    }
  }
  // If no positional arguments, it's the Install command
  if positional.is_empty() {
    let force = check_force_flag(flags)
    return Install(force~)
  }
  // First positional argument is the subcommand
  let subcommand = positional[0]
  match subcommand {
    "list" => {
      check_no_extra_flags(flags)
      List
    }
    "info" => {
      check_no_extra_flags(flags)
      if positional.length() < 2 {
        raise MissingArgument("info requires a library name")
      }
      Info(name=positional[1])
    }
    "remove" => {
      check_no_extra_flags(flags)
      if positional.length() < 2 {
        raise MissingArgument("remove requires a library name")
      }
      Remove(name=positional[1])
    }
    "repo" => {
      check_no_extra_flags(flags)
      parse_repo_subcommand(positional)
    }
    "cache" => {
      check_no_extra_flags(flags)
      parse_cache_subcommand(positional)
    }
    _ => raise UnknownCommand(subcommand)
  }
}

///|
/// Check for --force flag and validate no unknown flags
fn check_force_flag(flags : Array[String]) -> Bool raise ParseError {
  let mut force = false
  for flag in flags {
    match flag {
      "--force" => force = true
      _ => raise UnknownFlag(flag)
    }
  }
  force
}

///|
/// Validate that no extra flags are present
fn check_no_extra_flags(flags : Array[String]) -> Unit raise ParseError {
  for flag in flags {
    raise UnknownFlag(flag)
  }
}

///|
/// Parse repo subcommands
fn parse_repo_subcommand(
  positional : Array[String],
) -> Command raise ParseError {
  if positional.length() < 2 {
    raise MissingArgument(
      "repo requires a subcommand (list, add, remove, update)",
    )
  }
  let sub = positional[1]
  match sub {
    "list" => RepoList
    "add" => {
      if positional.length() < 3 {
        raise MissingArgument("repo add requires a URL")
      }
      RepoAdd(url=positional[2])
    }
    "remove" => {
      if positional.length() < 3 {
        raise MissingArgument("repo remove requires a URL")
      }
      RepoRemove(url=positional[2])
    }
    "update" => RepoUpdate
    _ => raise UnknownCommand("repo " + sub)
  }
}

///|
/// Parse cache subcommands
fn parse_cache_subcommand(
  positional : Array[String],
) -> Command raise ParseError {
  if positional.length() < 2 {
    raise MissingArgument("cache requires a subcommand (list, clean)")
  }
  let sub = positional[1]
  match sub {
    "list" => CacheList
    "clean" => CacheClean
    _ => raise UnknownCommand("cache " + sub)
  }
}
