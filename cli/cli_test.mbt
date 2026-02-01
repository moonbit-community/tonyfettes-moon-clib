// Test Install command (default)
test "parse_args: empty args returns Install(force=false)" {
  let cmd = @cli.parse_args([])
  assert_eq(cmd, @cli.Command::Install(force=false))
}

test "parse_args: --force returns Install(force=true)" {
  let cmd = @cli.parse_args(["--force"])
  assert_eq(cmd, @cli.Command::Install(force=true))
}

// Test Help command
test "parse_args: --help returns Help" {
  let cmd = @cli.parse_args(["--help"])
  assert_eq(cmd, @cli.Command::Help)
}

test "parse_args: -h returns Help" {
  let cmd = @cli.parse_args(["-h"])
  assert_eq(cmd, @cli.Command::Help)
}

test "parse_args: --help takes precedence over other args" {
  let cmd = @cli.parse_args(["list", "--help"])
  assert_eq(cmd, @cli.Command::Help)
}

// Test Version command
test "parse_args: --version returns Version" {
  let cmd = @cli.parse_args(["--version"])
  assert_eq(cmd, @cli.Command::Version)
}

test "parse_args: -v returns Version" {
  let cmd = @cli.parse_args(["-v"])
  assert_eq(cmd, @cli.Command::Version)
}

// Test List command
test "parse_args: list returns List" {
  let cmd = @cli.parse_args(["list"])
  assert_eq(cmd, @cli.Command::List)
}

// Test Info command
test "parse_args: info <name> returns Info" {
  let cmd = @cli.parse_args(["info", "zlib"])
  assert_eq(cmd, @cli.Command::Info(name="zlib"))
}

test "parse_args: info without name returns MissingArgument" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["info"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::MissingArgument(msg)) else {
    fail("Expected MissingArgument error")
  }
  assert_true(msg.contains("info"))
}

// Test Remove command
test "parse_args: remove <name> returns Remove" {
  let cmd = @cli.parse_args(["remove", "openssl"])
  assert_eq(cmd, @cli.Command::Remove(name="openssl"))
}

test "parse_args: remove without name returns MissingArgument" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["remove"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::MissingArgument(msg)) else {
    fail("Expected MissingArgument error")
  }
  assert_true(msg.contains("remove"))
}

// Test Repo subcommands
test "parse_args: repo list returns RepoList" {
  let cmd = @cli.parse_args(["repo", "list"])
  assert_eq(cmd, @cli.Command::RepoList)
}

test "parse_args: repo add <url> returns RepoAdd" {
  let cmd = @cli.parse_args(["repo", "add", "https://example.com/packages"])
  assert_eq(cmd, @cli.Command::RepoAdd(url="https://example.com/packages"))
}

test "parse_args: repo add without url returns MissingArgument" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["repo", "add"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::MissingArgument(msg)) else {
    fail("Expected MissingArgument error")
  }
  assert_true(msg.contains("URL"))
}

test "parse_args: repo remove <url> returns RepoRemove" {
  let cmd = @cli.parse_args(["repo", "remove", "/local/packages"])
  assert_eq(cmd, @cli.Command::RepoRemove(url="/local/packages"))
}

test "parse_args: repo remove without url returns MissingArgument" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["repo", "remove"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::MissingArgument(msg)) else {
    fail("Expected MissingArgument error")
  }
  assert_true(msg.contains("URL"))
}

test "parse_args: repo update returns RepoUpdate" {
  let cmd = @cli.parse_args(["repo", "update"])
  assert_eq(cmd, @cli.Command::RepoUpdate)
}

test "parse_args: repo without subcommand returns MissingArgument" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["repo"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::MissingArgument(msg)) else {
    fail("Expected MissingArgument error")
  }
  assert_true(msg.contains("repo"))
}

test "parse_args: repo unknown returns UnknownCommand" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["repo", "unknown"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::UnknownCommand(cmd)) else {
    fail("Expected UnknownCommand error")
  }
  assert_eq(cmd, "repo unknown")
}

// Test Cache subcommands
test "parse_args: cache list returns CacheList" {
  let cmd = @cli.parse_args(["cache", "list"])
  assert_eq(cmd, @cli.Command::CacheList)
}

test "parse_args: cache clean returns CacheClean" {
  let cmd = @cli.parse_args(["cache", "clean"])
  assert_eq(cmd, @cli.Command::CacheClean)
}

test "parse_args: cache without subcommand returns MissingArgument" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["cache"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::MissingArgument(msg)) else {
    fail("Expected MissingArgument error")
  }
  assert_true(msg.contains("cache"))
}

test "parse_args: cache unknown returns UnknownCommand" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["cache", "unknown"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::UnknownCommand(cmd)) else {
    fail("Expected UnknownCommand error")
  }
  assert_eq(cmd, "cache unknown")
}

// Test Unknown command error
test "parse_args: unknown command returns UnknownCommand" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["unknown"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::UnknownCommand(cmd)) else {
    fail("Expected UnknownCommand error")
  }
  assert_eq(cmd, "unknown")
}

// Test Unknown flag errors
test "parse_args: unknown flag returns UnknownFlag" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["--unknown"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::UnknownFlag(flag)) else {
    fail("Expected UnknownFlag error")
  }
  assert_eq(flag, "--unknown")
}

test "parse_args: --force with subcommand returns UnknownFlag" {
  let result : Result[@cli.Command, @cli.ParseError] = try {
    Ok(@cli.parse_args(["list", "--force"]))
  } catch {
    e => Err(e)
  }
  guard result is Err(@cli.ParseError::UnknownFlag(flag)) else {
    fail("Expected UnknownFlag error")
  }
  assert_eq(flag, "--force")
}

// Test flag position independence
test "parse_args: --force before subcommand works" {
  // --force without a subcommand should still be Install(force=true)
  let cmd = @cli.parse_args(["--force"])
  assert_eq(cmd, @cli.Command::Install(force=true))
}

// Test Show derive for Command
test "Command: Show derive works" {
  let cmd : @cli.Command = @cli.Command::Install(force=true)
  let s = cmd.to_string()
  assert_true(s.contains("Install"))
}

// Test Eq derive for Command
test "Command: Eq derive works" {
  let cmd1 : @cli.Command = @cli.Command::Info(name="zlib")
  let cmd2 : @cli.Command = @cli.Command::Info(name="zlib")
  let cmd3 : @cli.Command = @cli.Command::Info(name="openssl")
  assert_eq(cmd1, cmd2)
  assert_not_eq(cmd1, cmd3)
}
