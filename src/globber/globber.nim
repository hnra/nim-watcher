import std/[os,re, strformat, strutils]

proc pathParts*(path: string): seq[string] =
  let (h, t) = splitPath(path)

  if h == path:
    if h == "":
      return @[]
    else:
      return @[h]
  else:
    var parts = pathParts(h)

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

  for kind, path in walkDir(basePath):
    case kind:
    of pcFile:
      if contains(path, pattern):
        matches.add(path)
    of pcDir:
      matches.add(getFilesRecursive(path, pattern))
    else: discard

  return matches

proc addTrailingDirSep(path: string): string =
  if len(path) > 0 and path[^1] != DirSep:
    return path & DirSep
  return path

proc globToPattern(glob: string, base: string): string =
  var baseRe = escapeRe(addTrailingDirSep(base))
  if len(baseRe) > 0:
    baseRe = "^" & baseRe

  const star = escapeRe("*")
  const dblStar = star & star
  let sep = escapeRe($DirSep)

  var pattern = escapeRe(glob)

  pattern = replace(pattern, dblStar & sep, ".*")
  pattern = replace(pattern, star, fmt"[^{sep}]*")
  pattern = replace(pattern, ".*.*", ".*")

  return baseRe & pattern & "$"

proc getDeepestBase(basePath: string, glob: string): (string, string) =
  let parts = pathParts(joinPath(basePath, glob))
  
  var deepBase = ""
  var restGlob = ""
  var hasSplit = false
  for i, p in parts:
    if p == "**" or i == len(parts) - 1:
      hasSplit = true
    if hasSplit:
      restGlob = restGlob / p
    else:
      deepBase = deepBase / p

  return (deepBase, restGlob)

proc getFilesRecursive*(basePath: string, glob: string): seq[string] =
  let (base, glob) = getDeepestBase(basePath, glob)

  let pattern = re(globToPattern(glob, base))
  return getFilesRecursive(base, pattern)

