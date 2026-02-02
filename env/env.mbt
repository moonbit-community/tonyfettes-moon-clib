///| Environment detection and path utilities for moon-clib

///|
/// Error type for environment operations
pub suberror EnvError {
  EnvError(String)
}

///| Get the current operating system.

///|
/// Returns "darwin", "linux", or "windows".
pub async fn get_os() -> String {
  let (exit_code, output) = @process.collect_stdout("uname", ["-s"])
  if exit_code != 0 {
    // Fallback: assume windows if uname fails
    return "windows"
  }
  let os_name = output.text().trim(char_set="\n\r ").to_string()
  match os_name {
    "Darwin" => "darwin"
    "Linux" => "linux"
    _ => os_name
  }
}

///| Get the current CPU architecture.

///|
/// Returns "x86_64", "aarch64", etc.
pub async fn get_arch() -> String {
  let (exit_code, output) = @process.collect_stdout("uname", ["-m"])
  if exit_code != 0 {
    // Fallback: default to x86_64
    return "x86_64"
  }
  let arch_name = output.text().trim(char_set="\n\r ").to_string()
  normalize_arch(arch_name)
}

///|
/// Normalize architecture names to consistent values.
fn normalize_arch(arch : String) -> String {
  match arch {
    "arm64" => "aarch64"
    "amd64" => "x86_64"
    "i386" | "i486" | "i586" | "i686" => "x86"
    _ => arch
  }
}

///|
/// Get the number of CPU cores available for parallel jobs.
pub async fn get_jobs() -> Int {
  let os = get_os()
  let (exit_code, output) = if os == "darwin" {
    @process.collect_stdout("sysctl", ["-n", "hw.ncpu"])
  } else {
    // Linux and others
    @process.collect_stdout("nproc", [])
  }
  if exit_code != 0 {
    // Fallback: default to 1
    return 1
  }
  let jobs_str = output.text().trim(char_set="\n\r ").to_string()
  try {
    let n = @strconv.parse_int(jobs_str)
    if n > 0 {
      n
    } else {
      1
    }
  } catch {
    _ => 1
  }
}

///|
/// Get environment variable value using printenv.
async fn get_env_var(name : String) -> String? {
  let (exit_code, output) = @process.collect_stdout("printenv", [name])
  if exit_code != 0 {
    return None
  }
  let value = output.text().trim(char_set="\n\r ").to_string()
  if value.is_empty() {
    None
  } else {
    Some(value)
  }
}

///| Get the MOON_HOME directory.

///|
/// Returns $MOON_HOME if set, otherwise defaults to ~/.moon
pub async fn get_moon_home() -> String {
  match get_env_var("MOON_HOME") {
    Some(home) => home
    None => {
      let home_dir = get_home_dir()
      home_dir + "/.moon"
    }
  }
}

///| Get the cache directory for moon-clib.

///| On macOS: ~/Library/Caches/moon-clib

///|
/// On Linux: $XDG_CACHE_HOME/moon-clib or ~/.cache/moon-clib
pub async fn get_cache_dir() -> String {
  // First check for override environment variable
  match get_env_var("MOON_CLIB_CACHE") {
    Some(cache) => return cache
    None => ()
  }
  let os = get_os()
  let home_dir = get_home_dir()
  if os == "darwin" {
    home_dir + "/Library/Caches/moon-clib"
  } else {
    // Linux: use XDG_CACHE_HOME or default
    match get_env_var("XDG_CACHE_HOME") {
      Some(xdg_cache) => xdg_cache + "/moon-clib"
      None => home_dir + "/.cache/moon-clib"
    }
  }
}

///| Get the config directory for moon-clib.

///|
/// Defaults to ~/.config/moon-clib
pub async fn get_config_dir() -> String {
  let home_dir = get_home_dir()
  // Check for XDG_CONFIG_HOME on Linux
  let os = get_os()
  if os != "darwin" {
    match get_env_var("XDG_CONFIG_HOME") {
      Some(xdg_config) => return xdg_config + "/moon-clib"
      None => ()
    }
  }
  home_dir + "/.config/moon-clib"
}

///|
/// Get the user's home directory.
pub async fn get_home_dir() -> String {
  // Try HOME first (works on Unix-like systems)
  match get_env_var("HOME") {
    Some(home) => return home
    None => ()
  }
  // Try USERPROFILE for Windows
  match get_env_var("USERPROFILE") {
    Some(profile) => return profile
    None => ()
  }
  // Fallback: try to get from shell expansion
  let (exit_code, output) = @process.collect_stdout("sh", ["-c", "echo $HOME"])
  if exit_code == 0 {
    let home = output.text().trim(char_set="\n\r ").to_string()
    if not(home.is_empty()) {
      return home
    }
  }
  raise EnvError("Could not determine home directory")
}
