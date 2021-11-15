import std/[os,re, strformat, strutils]

proc pathParts*(path: string): seq[string] {.noSideEffect} =
  ## Splits a path into a sequence of its parts,
  ## so that `path == path.pathParts.joinPath`.
  runnableExamples:
    import std/os

    when defined(posix):
      assert pathParts("/usr/local/bin") == @["/", "usr", "local", "bin"]
      assert pathParts("/usr/local/bin").joinPath == "/usr/local/bin"

    when defined(windows):
      assert pathParts(r"C:\Users\nim") == @["C:", "Users", "nim"]
      assert pathParts(r"C:\Users\nim").joinPath == r"C:\Users\nim"

  let (h, t) = path.splitPath

  if h == path:
    if h == "":
      return @[]
    else:
      return @[h]
  else:
    var parts = h.pathParts

    if t != "":
      parts.add(t)
    return parts

proc splitAt*[T](f: proc(t: T): bool, xs: seq[T]): (seq[T], seq[T]) {.noSideEffect} =
  ## Splits a sequence where `f` is `true`.
  runnableExamples:
    import std/seqUtils
    proc positive(x: int): bool = x > -1
    assert splitAt(positive, toSeq(-3..3)) == (@[-3, -2, -1], @[0, 1, 2, 3])

  var head = newSeq[T]()
  var tail = newSeq[T]()
  var hasSplit = false

  for x in xs:
    hasSplit = hasSplit or f(x)
    if hasSplit:
      tail.add(x)
    else:
      head.add(x)
  return (head, tail)

proc getFilesRecursive(basePath: string, pattern: Regex): seq[string] =
  var matches = newSeq[string]()

  for kind, path in basePath.walkDir:
    case kind:
    of pcFile:
      if path.contains(pattern):
        matches.add(path)
    of pcDir:
      matches.add(path.getFilesRecursive(pattern))
    else: discard

  return matches

proc addTrailingDirSep(path: string, dirSep = $DirSep): string =
  if path.len > 0 and path[^1] != dirSep[0]:
    return path & dirSep
  return path

proc globToPattern*(glob: string, base = "", dirSep = $DirSep): string {.noSideEffect} =
  ## Converts a file glob to a regex pattern, according to:
  ## 1. Convert `**/` to `.*`.
  ## 2. Convert `*` to `[^DirSep]*`.
  ## 3. Add `^base` to start if `base != ""`.
  ## 4. Add `$` to end.
  runnableExamples:
    import std/[re, strformat]
    const dot = ".".escapeRe

    const unixSep = "/".escapeRe
    assert globToPattern("**/*.nim", dirSep="/") ==
      fmt".*[^{unixSep}]*{dot}nim$"
    assert globToPattern("**/*.nim", "/", "/") ==
      fmt"^{unixSep}.*[^{unixSep}]*{dot}nim$"

    const winSep = r"\".escapeRe
    const col = ":".escapeRe
    assert globToPattern(r"**\*.nim", dirSep=r"\") ==
      fmt".*[^{winSep}]*{dot}nim$"
    assert globToPattern(r"**\*.nim", r"C:\", dirSep=r"\") ==
      fmt"^C{col}{winSep}.*[^{winSep}]*{dot}nim$"

  var baseRe = base.addTrailingDirSep(dirSep).escapeRe
  if baseRe.len > 0:
    baseRe = "^" & baseRe

  const star = "*".escapeRe
  const dblStar = star & star
  let sep = dirSep.escapeRe

  var pattern = glob.escapeRe

  pattern = replace(pattern, dblStar & sep, ".*")
  pattern = replace(pattern, star, fmt"[^{sep}]*")
  pattern = replace(pattern, ".*.*", ".*")

  return baseRe & pattern & "$"

proc getDeepestBase(basePath: string, glob: string): (string, string) =
  let parts = basePath.joinPath(glob).pathParts
  
  var deepBase = ""
  var restGlob = ""
  var hasSplit = false
  for i, p in parts:
    if p == "**" or i == parts.len - 1:
      hasSplit = true
    if hasSplit:
      restGlob = restGlob / p
    else:
      deepBase = deepBase / p

  return (deepBase, restGlob)

proc getFilesRecursive*(basePath: string, glob: string): seq[string] =
  ## Gets all files which matches `glob` from path `basePath`.
  ## Allowed symbols in a glob are: `..`, `*`, and `**`.

  let (base, glob) = basePath.getDeepestBase(glob)

  let pattern = glob.globToPattern(base).re
  return base.getFilesRecursive(pattern)

