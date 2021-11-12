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

proc takeWhile*[T](f: proc(t: T): bool, xs: seq[T]): seq[T] =
  var ys: seq[T] = @[]
  for x in xs:
    if f(x):
      ys.add(x)
    else:
      break
  return ys

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

proc baseDir*(glob: string): (string, seq[string]) =
  let parts = pathParts(glob)
  var (base, glob) = splitAt(( proc (p: string): bool = p == "**" ), parts)
  
  if len(glob) == 0:
    glob = base[^1 .. ^1]
    base = base[0 .. ^2]
  return (joinPath(base), glob)

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

proc globToPattern*(glob: string, base = ""): string =
  var b = base
  if len(b) > 0 and b[^1] != DirSep:
    b = fmt"{b}{DirSep}"
  var baseRe = escapeRe(b)
  if len(baseRe) > 0:
    baseRe = "^" & baseRe

  const star = escapeRe("*")
  const dblStar = star & star
  const fslash = escapeRe("/")

  var pattern = escapeRe(glob)

  pattern = replace(pattern, dblStar & fslash, ".*")
  pattern = replace(pattern, star, fmt"[^{fslash}]*")
  pattern = replace(pattern, ".*.*", ".*")

  return fmt"{baseRe}{pattern}$"

proc getFilesRecursive*(basePath: string, glob: string): seq[string] =
  let parts = pathParts(joinPath(basePath, glob))
  
  var absBase = ""
  var relGlob = ""
  var hasSplit = false
  for i, p in parts:
    if p == "**" or i == len(parts) - 1:
      hasSplit = true
    if hasSplit:
      relGlob = relGlob / p
    else:
      absBase = absBase / p

  let pattern = re(globToPattern(relGlob, absBase))
  return getFilesRecursive(absBase, pattern)

