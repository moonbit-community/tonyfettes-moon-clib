///| Tests for error formatting

///|
test "format_error: missing moon.lib.json" {
  let (message, hints, details) = format_error(
    @config.ConfigError::ReadFile(
      "./moon.lib.json",
      "No such file or directory",
    ),
    false,
  )
  assert_eq(message, "No `moon.lib.json` found in the current directory.")
  assert_true(details is None)
  let mut has_hint = false
  for hint in hints {
    if hint.contains("moon.lib.json") {
      has_hint = true
    }
  }
  assert_true(has_hint)
}

///|
test "format_error: verbose details" {
  let (message, _, details) = format_error(
    @builder.BuildError::CommandFailed(2, "make all"),
    true,
  )
  assert_eq(message, "Build step failed.")
  guard details is Some(d) else { fail("Expected details") }
  assert_true(d.contains("exit code 2"))
}
