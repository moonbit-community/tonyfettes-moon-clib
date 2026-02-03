///|
/// Build context containing all variables for expansion
pub(all) struct BuildContext {
  prefix : String // $MOON_HOME
  destdir : String // Temp staging directory
  srcdir : String // Source directory
  jobs : Int // Parallel job count
  os : String // Current OS
  arch : String // Current architecture
} derive(Show, Eq)

///|
/// Error type for builder operations
pub suberror BuildError {
  EmptyRunArray
  CommandFailed(Int, String)
}

///|
/// Human-readable error output
pub impl Show for BuildError with output(
  self : BuildError,
  logger : &@builtin.Logger,
) -> Unit {
  match self {
    EmptyRunArray => logger.write_string("Build step has empty run array")
    CommandFailed(code, cmd) =>
      logger.write_string("Command failed with exit code \{code}: \{cmd}")
  }
}

///| Expand variables in a string using the build context.

///|
/// Replaces ${VAR} patterns with their corresponding values.
pub fn expand_variables(s : String, ctx : BuildContext) -> String {
  let result = StringBuilder::new()
  let chars = s.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    if i + 1 < len && chars[i] == '$' && chars[i + 1] == '{' {
      // Find closing brace
      let start = i + 2
      let mut end = start
      while end < len && chars[end] != '}' {
        end = end + 1
      }
      if end < len {
        // Extract variable name from chars
        let var_builder = StringBuilder::new()
        for j = start; j < end; j = j + 1 {
          var_builder.write_char(chars[j])
        }
        let var_name = var_builder.to_string()
        // Replace with value
        let value = match var_name {
          "PREFIX" => ctx.prefix
          "DESTDIR" => ctx.destdir
          "JOBS" => ctx.jobs.to_string()
          "SRCDIR" => ctx.srcdir
          "OS" => ctx.os
          "ARCH" => ctx.arch
          _ => "${" + var_name + "}" // Keep unknown variables as-is
        }
        result.write_string(value)
        i = end + 1
      } else {
        // No closing brace found, keep literal
        result.write_char(chars[i])
        i = i + 1
      }
    } else {
      result.write_char(chars[i])
      i = i + 1
    }
  }
  result.to_string()
}

///| Check if a condition matches the current OS and architecture.

///| - If condition is None, step always runs

///| - If os is Some, must match current os

///| - If arch is Some, must match current arch

///|
/// - If both specified, both must match
pub fn matches_condition(
  cond : @types.Condition?,
  os : String,
  arch : String,
) -> Bool {
  match cond {
    None => true
    Some(c) => {
      let os_matches = match c.os {
        None => true
        Some(cond_os) => cond_os == os
      }
      let arch_matches = match c.arch {
        None => true
        Some(cond_arch) => cond_arch == arch
      }
      os_matches && arch_matches
    }
  }
}

///| Execute a sequence of build steps.

///| - Expands variables in all run array elements

///| - Respects condition matching for each step

///| - cwd is relative to srcdir

///|
/// - Raises on non-zero exit code
pub async fn execute_build(
  steps : Array[@types.BuildStep],
  ctx : BuildContext,
) -> Unit {
  for step in steps {
    // Check if condition matches
    if not(matches_condition(step.when, ctx.os, ctx.arch)) {
      continue
    }

    // Expand variables in command array
    let expanded_cmd : Array[String] = []
    for arg in step.run {
      expanded_cmd.push(expand_variables(arg, ctx))
    }

    // Must have at least one element (the command)
    if expanded_cmd.is_empty() {
      raise EmptyRunArray
    }
    let cmd = expanded_cmd[0]
    let args : Array[String] = []
    for i = 1; i < expanded_cmd.length(); i = i + 1 {
      args.push(expanded_cmd[i])
    }

    // Determine working directory
    let cwd : String? = match step.cwd {
      None => Some(ctx.srcdir)
      Some(rel_cwd) => Some(ctx.srcdir + "/" + rel_cwd)
    }

    // Build extra environment variables (expand ${VAR} in values)
    let extra_env : Map[String, String] = match step.env {
      None => {}
      Some(env) => {
        let expanded : Map[String, String] = {}
        for key, value in env {
          expanded[key] = expand_variables(value, ctx)
        }
        expanded
      }
    }

    // Execute the command
    let exit_code = @process.run(
      cmd,
      args[:],
      cwd?=cwd.map(fn(s) { s.view() }),
      extra_env~,
    )
    if exit_code != 0 {
      let cmd_str = expanded_cmd
        .iter()
        .fold(init="", fn(acc, s) {
          if acc.is_empty() {
            s
          } else {
            acc + " " + s
          }
        })
      raise CommandFailed(exit_code, cmd_str)
    }
  }
}
