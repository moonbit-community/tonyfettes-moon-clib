///| Dependency resolution with topological sort for moon-clib

///|
/// Error type for resolver operations
pub suberror ResolverError {
  CircularDependency(String)
  PackageNotFound(String, String)
  ResolutionError(String)
}

///|
/// Human-readable error output
pub impl Show for ResolverError with output(
  self : ResolverError,
  logger : &@builtin.Logger,
) -> Unit {
  match self {
    CircularDependency(msg) => logger.write_string(msg)
    PackageNotFound(name, version) =>
      logger.write_string("Package not found: \{name}@\{version}")
    ResolutionError(msg) => logger.write_string(msg)
  }
}

///|
/// A resolved package with its manifest and source repository
pub(all) struct ResolvedPackage {
  name : String
  version : String
  manifest : @types.PackageManifest
  repository : @repository.Repository
} derive(Show, Eq)

///|
/// Internal node for building the dependency graph
priv struct DepNode {
  name : String
  version : String
  manifest : @types.PackageManifest
  repository : @repository.Repository
  dependencies : Array[String] // keys into the graph (name@version)
}

///|
/// Create a unique key for a package
fn make_key(name : String, version : String) -> String {
  "\{name}@\{version}"
}

///| Resolve all dependencies starting from the given deps map.

///|
/// Returns packages in topological order (dependencies before dependents).
pub async fn resolve_dependencies(
  deps : Map[String, String],
  repos : Array[@repository.Repository],
) -> Array[ResolvedPackage] {
  // Build the complete dependency graph
  let graph : Map[String, DepNode] = {}
  // Track nodes currently in the DFS path (for cycle detection)
  let in_path : Map[String, Bool] = {}

  // Process all top-level dependencies
  for name, version in deps {
    build_graph(name, version, repos, graph, in_path)
  }

  // Perform topological sort
  topological_sort(graph)
}

///|
/// Recursively build the dependency graph.
async fn build_graph(
  name : String,
  version : String,
  repos : Array[@repository.Repository],
  graph : Map[String, DepNode],
  in_path : Map[String, Bool],
) -> Unit {
  let key = make_key(name, version)

  // Skip if already fully processed
  if graph.contains(key) {
    // But check if it's in the current path (cycle)
    match in_path.get(key) {
      Some(true) =>
        raise CircularDependency(
          "Circular dependency detected involving \{name}@\{version}",
        )
      _ => ()
    }
    return
  }

  // Check for cycle (currently being visited in this DFS path)
  match in_path.get(key) {
    Some(true) =>
      raise CircularDependency(
        "Circular dependency detected involving \{name}@\{version}",
      )
    _ => ()
  }

  // Mark as in current path
  in_path[key] = true

  // Fetch the manifest
  let (repository, manifest) = @repository.find_package(repos, name, version) catch {
    @repository.PackageNotFound(n, v) => raise PackageNotFound(n, v)
    err => raise ResolutionError("Failed to fetch \{name}@\{version}: \{err}")
  }

  // Get dependencies of this package
  let dep_keys : Array[String] = []
  match manifest.dependencies {
    Some(pkg_deps) =>
      for dep_name, dep_version in pkg_deps {
        dep_keys.push(make_key(dep_name, dep_version))
        // Recursively process each dependency
        build_graph(dep_name, dep_version, repos, graph, in_path)
      }
    None => ()
  }

  // Add node to graph (marks as fully processed)
  graph[key] = { name, version, manifest, repository, dependencies: dep_keys }

  // Remove from current path
  in_path[key] = false
}

///| Perform topological sort using Kahn's algorithm.

///|
/// Returns packages in order where dependencies come before dependents.
fn topological_sort(
  graph : Map[String, DepNode],
) -> Array[ResolvedPackage] raise {
  // We need to reverse the edge direction for topological sort:
  // If A depends on B, B must come before A in the output.
  // So we track "dependents" - which packages depend on each package.
  // A package can be processed when all its dependencies have been processed.
  //
  // Use out-degree (number of dependencies) instead of in-degree.
  // Start with packages that have no dependencies.

  // Track remaining dependency count for each node
  let remaining_deps : Map[String, Int] = {}

  // Build reverse edges: for each package, which packages depend on it
  let dependents : Map[String, Array[String]] = {}

  // Initialize
  for key, node in graph {
    remaining_deps[key] = node.dependencies.length()
    dependents[key] = []
  }

  // Build reverse edges
  for key, node in graph {
    for dep_key in node.dependencies {
      guard dependents.get(dep_key) is Some(dep_list) else { continue }
      dep_list.push(key)
    }
  }

  // Start with nodes that have no dependencies
  let queue : Array[String] = []
  for key, count in remaining_deps {
    if count == 0 {
      queue.push(key)
    }
  }

  // Process nodes in topological order
  let result : Array[ResolvedPackage] = []
  while queue.length() > 0 {
    // Get next node with no remaining dependencies
    guard queue.pop() is Some(key) else { break }

    // Add to result
    guard graph.get(key) is Some(node) else { continue }
    result.push({
      name: node.name,
      version: node.version,
      manifest: node.manifest,
      repository: node.repository,
    })

    // For each package that depends on this one, decrement its remaining deps
    guard dependents.get(key) is Some(dep_list) else { continue }
    for dependent_key in dep_list {
      match remaining_deps.get(dependent_key) {
        Some(count) => {
          let new_count = count - 1
          remaining_deps[dependent_key] = new_count
          if new_count == 0 {
            queue.push(dependent_key)
          }
        }
        None => ()
      }
    }
  }

  // Check if all nodes were processed (no cycles)
  if result.length() != graph.length() {
    // Find nodes that weren't processed (part of a cycle)
    let cycle_nodes : Array[String] = []
    for key, count in remaining_deps {
      if count > 0 {
        cycle_nodes.push(key)
      }
    }
    raise CircularDependency(
      "Circular dependency detected involving: \{cycle_nodes.iter().collect()}",
    )
  }
  result
}
