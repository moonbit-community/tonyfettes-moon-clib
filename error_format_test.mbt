///| Tests for error formatting

///|
async test "format_error: missing moon.lib.json" {
  let result : Result[@types.ProjectDependencies, Error] = Ok(
    @config.load_project_deps_from("/nonexistent/moon.lib.json"),
  ) catch {
    err => Err(err)
  }
  let err = match result {
    Err(e) => e
    Ok(_) => fail("Expected missing file error")
  }
  let (message, hints, details) = format_error(err, false)
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
async test "format_error: verbose details" {
  let ctx : @builder.BuildContext = {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
  let steps : Array[@types.BuildStep] = [
    { run: ["false"], when: None, env: None, cwd: None },
  ]
  let result : Result[Unit, Error] = Ok(
    @builder.execute_build(steps, ctx),
  ) catch {
    err => Err(err)
  }
  let err = match result {
    Err(e) => e
    Ok(_) => fail("Expected build failure")
  }
  let (message, _, details) = format_error(err, true)
  assert_eq(message, "Build step failed.")
  guard details is Some(d) else { fail("Expected details") }
  assert_true(d.contains("exit code"))
}
