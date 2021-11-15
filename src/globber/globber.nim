import std/[os,re, strformat, strutils]

proc pathParts*(path: string): seq[string] =
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

proc splitAt*[T](f: proc(t: T): bool, xs: seq[T]): (seq[T], seq[T]) =
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

proc addTrailingDirSep(path: string): string =
  if path.len > 0 and path[^1] != DirSep:
    return path & DirSep
  return path

proc globToPattern(glob: string, base: string): string =
  var baseRe = base.addTrailingDirSep.escapeRe
  if baseRe.len > 0:
    baseRe = "^" & baseRe

  const star = "*".escapeRe
  const dblStar = star & star
  let sep = ($DirSep).escapeRe

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
  let (base, glob) = basePath.getDeepestBase(glob)

  let pattern = glob.globToPattern(base).re
  return base.getFilesRecursive(pattern)

