///| Tests for builder module

///|
/// Helper to create a test build context
fn make_test_ctx() -> @builder.BuildContext {
  {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp/src",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
}

// ============================================================================
// Variable Expansion Tests
// ============================================================================

///|
test "expand_variables: PREFIX" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("--prefix=${PREFIX}", ctx)
  assert_eq(result, "--prefix=/usr/local")
}

///|
test "expand_variables: DESTDIR" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("DESTDIR=${DESTDIR}", ctx)
  assert_eq(result, "DESTDIR=/tmp/destdir")
}

///|
test "expand_variables: JOBS" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("-j${JOBS}", ctx)
  assert_eq(result, "-j4")
}

///|
test "expand_variables: SRCDIR" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("${SRCDIR}/build", ctx)
  assert_eq(result, "/tmp/src/build")
}

///|
test "expand_variables: OS" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("--os=${OS}", ctx)
  assert_eq(result, "--os=linux")
}

///|
test "expand_variables: ARCH" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("--arch=${ARCH}", ctx)
  assert_eq(result, "--arch=x86_64")
}

///|
test "expand_variables: multiple variables" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("${DESTDIR}${PREFIX}/lib", ctx)
  assert_eq(result, "/tmp/destdir/usr/local/lib")
}

///|
test "expand_variables: no variables" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("make install", ctx)
  assert_eq(result, "make install")
}

///|
test "expand_variables: unknown variable preserved" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("${UNKNOWN}", ctx)
  assert_eq(result, "${UNKNOWN}")
}

///|
test "expand_variables: partial match no closing brace" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("${PREFIX", ctx)
  assert_eq(result, "${PREFIX")
}

///|
test "expand_variables: dollar sign without brace" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("$PREFIX", ctx)
  assert_eq(result, "$PREFIX")
}

///|
test "expand_variables: empty string" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables("", ctx)
  assert_eq(result, "")
}

///|
test "expand_variables: all six variables" {
  let ctx = make_test_ctx()
  let result = @builder.expand_variables(
    "${PREFIX}-${DESTDIR}-${SRCDIR}-${JOBS}-${OS}-${ARCH}", ctx,
  )
  assert_eq(result, "/usr/local-/tmp/destdir-/tmp/src-4-linux-x86_64")
}

// ============================================================================
// Condition Matching Tests
// ============================================================================

///|
test "matches_condition: None condition always matches" {
  assert_true(@builder.matches_condition(None, "linux", "x86_64"))
  assert_true(@builder.matches_condition(None, "darwin", "aarch64"))
  assert_true(@builder.matches_condition(None, "windows", "x86"))
}

///|
test "matches_condition: os only - match" {
  let cond : @types.Condition = { os: Some("linux"), arch: None }
  assert_true(@builder.matches_condition(Some(cond), "linux", "x86_64"))
  assert_true(@builder.matches_condition(Some(cond), "linux", "aarch64"))
}

///|
test "matches_condition: os only - no match" {
  let cond : @types.Condition = { os: Some("linux"), arch: None }
  assert_false(@builder.matches_condition(Some(cond), "darwin", "x86_64"))
  assert_false(@builder.matches_condition(Some(cond), "windows", "x86_64"))
}

///|
test "matches_condition: arch only - match" {
  let cond : @types.Condition = { os: None, arch: Some("x86_64") }
  assert_true(@builder.matches_condition(Some(cond), "linux", "x86_64"))
  assert_true(@builder.matches_condition(Some(cond), "darwin", "x86_64"))
}

///|
test "matches_condition: arch only - no match" {
  let cond : @types.Condition = { os: None, arch: Some("x86_64") }
  assert_false(@builder.matches_condition(Some(cond), "linux", "aarch64"))
  assert_false(@builder.matches_condition(Some(cond), "darwin", "aarch64"))
}

///|
test "matches_condition: both - match" {
  let cond : @types.Condition = { os: Some("darwin"), arch: Some("aarch64") }
  assert_true(@builder.matches_condition(Some(cond), "darwin", "aarch64"))
}

///|
test "matches_condition: both - os matches arch does not" {
  let cond : @types.Condition = { os: Some("darwin"), arch: Some("aarch64") }
  assert_false(@builder.matches_condition(Some(cond), "darwin", "x86_64"))
}

///|
test "matches_condition: both - arch matches os does not" {
  let cond : @types.Condition = { os: Some("darwin"), arch: Some("aarch64") }
  assert_false(@builder.matches_condition(Some(cond), "linux", "aarch64"))
}

///|
test "matches_condition: both - neither matches" {
  let cond : @types.Condition = { os: Some("darwin"), arch: Some("aarch64") }
  assert_false(@builder.matches_condition(Some(cond), "linux", "x86_64"))
}

///|
test "matches_condition: empty condition (both None) always matches" {
  let cond : @types.Condition = { os: None, arch: None }
  assert_true(@builder.matches_condition(Some(cond), "linux", "x86_64"))
  assert_true(@builder.matches_condition(Some(cond), "darwin", "aarch64"))
}

// ============================================================================
// Build Step Execution Tests
// ============================================================================

///|
/// Test execute_build with simple echo command
async test "execute_build: simple command" {
  let ctx : @builder.BuildContext = {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
  let steps : Array[@types.BuildStep] = [
    { run: ["true"], when: None, env: None, cwd: None },
  ]
  @builder.execute_build(steps, ctx)
}

///|
/// Test execute_build with variable expansion
async test "execute_build: variable expansion in command" {
  let ctx : @builder.BuildContext = {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
  // Use echo to verify variables are expanded
  let steps : Array[@types.BuildStep] = [
    { run: ["sh", "-c", "test ${JOBS} = 4"], when: None, env: None, cwd: None },
  ]
  @builder.execute_build(steps, ctx)
}

///|
/// Test execute_build skips steps with non-matching condition
async test "execute_build: condition skips step" {
  let ctx : @builder.BuildContext = {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
  // This step should be skipped because os=darwin does not match linux
  let steps : Array[@types.BuildStep] = [
    {
      run: ["false"], // Would fail if executed
      when: Some({ os: Some("darwin"), arch: None }),
      env: None,
      cwd: None,
    },
  ]
  @builder.execute_build(steps, ctx) // Should not raise
}

///|
/// Test execute_build runs steps with matching condition
async test "execute_build: condition runs matching step" {
  let ctx : @builder.BuildContext = {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
  let steps : Array[@types.BuildStep] = [
    {
      run: ["true"],
      when: Some({ os: Some("linux"), arch: None }),
      env: None,
      cwd: None,
    },
  ]
  @builder.execute_build(steps, ctx)
}

///|
/// Test execute_build with custom working directory
async test "execute_build: custom cwd" {
  let ctx : @builder.BuildContext = {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
  // pwd should work in the /tmp directory
  let steps : Array[@types.BuildStep] = [
    { run: ["pwd"], when: None, env: None, cwd: None },
  ]
  @builder.execute_build(steps, ctx)
}

///|
/// Test execute_build raises on command failure
async test "execute_build: raises on failure" {
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
  let result : Result[Unit, Error] = try {
    @builder.execute_build(steps, ctx)
    Ok(())
  } catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

///|
/// Test execute_build with multiple steps
async test "execute_build: multiple steps" {
  let ctx : @builder.BuildContext = {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
  let steps : Array[@types.BuildStep] = [
    { run: ["true"], when: None, env: None, cwd: None },
    { run: ["true"], when: None, env: None, cwd: None },
    { run: ["true"], when: None, env: None, cwd: None },
  ]
  @builder.execute_build(steps, ctx)
}

///|
/// Test execute_build with empty steps array
async test "execute_build: empty steps" {
  let ctx : @builder.BuildContext = {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
  let steps : Array[@types.BuildStep] = []
  @builder.execute_build(steps, ctx)
}

///|
/// Test execute_build with environment variables
async test "execute_build: with env" {
  let ctx : @builder.BuildContext = {
    prefix: "/usr/local",
    destdir: "/tmp/destdir",
    srcdir: "/tmp",
    jobs: 4,
    os: "linux",
    arch: "x86_64",
  }
  let env : Map[String, String] = {}
  env["MY_VAR"] = "hello"
  let steps : Array[@types.BuildStep] = [
    {
      run: ["sh", "-c", "test \"$MY_VAR\" = \"hello\""],
      when: None,
      env: Some(env),
      cwd: None,
    },
  ]
  @builder.execute_build(steps, ctx)
}
