import std/[os, osproc, parseopt, times, tables, strformat]

import globber/globber

type
  ProgramArgs* = object
    verbose*: bool
    cmd*: string
    glob*: string

# proc validateGlob(glob: string): (bool, string) =
#   return (true, "")

proc parseArgs*(args: seq[string]): ProgramArgs =
  var watchGlob = "**/*.nim"
  var watchCmd = ""
  var verbose = false

  var p = initOptParser(args)
  while true:
    p.next()
    case p.kind:
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key:
      of "g", "glob":
        watchGlob = p.val
      of "v", "verbose":
        verbose = true
      else: discard
    of cmdArgument:
      if watchCmd == "":
        watchCmd = p.key
      else:
        watchCmd &= " " & p.key

  return ProgramArgs(verbose: verbose, cmd: watchCmd, glob: watchGlob)

type
  Log = proc (msg: string): void
  Level = enum info, warning, error
  Logger = object
    info*: Log
    warning*: Log
    error*: Log

proc createLogger(verbose: bool): Logger =
  proc log(level: Level): proc (msg:string): void =
    proc log(msg: string): void =
      case level:
      of info:
        if verbose:
          echo(msg)
      of warning, error:
        echo(msg)
    return log

  return Logger(info: log(info), warning: log(warning), error: log(error))

type
  FileCache = TableRef[string, Time]
  CacheUpdate = object
    removed: seq[string]
    updates: seq[(string, Time)]

proc createCache(paths: seq[string]): FileCache =
  var cache = newTable[string, Time]()

  for f in paths:
    let mtime = getLastModificationTime f
    cache[f] = mtime

  return cache

proc hasChanged(cache: FileCache): CacheUpdate =
  var removed = newSeq[string]()
  var updates = newSeq[(string, Time)]()

  for f, t in cache.pairs:
    if fileExists(f):
      let mtime = getlastmodificationtime f
      if mtime > t:
        updates.add((f, mtime))
        break
    else:
      removed.add(f)
  return CacheUpdate(removed: removed, updates: updates)

proc newFiles(cache: FileCache, files: seq[string]): CacheUpdate =
  const removed = newSeq[string]()
  var updates = newSeq[(string, Time)]()
  for f in files:
    if not (f in cache):
      let mtime = getlastmodificationtime f
      updates.add((f, mtime))
  return CacheUpdate(removed: removed, updates: updates)

when isMainModule:
  let args = parseArgs(commandLineParams())
  let log = createLogger(args.verbose)

  proc ls(): seq[string] =
    return getFilesRecursive(getCurrentDir() , args.glob)

  proc run(): int =
    let exitCode = execCmd(args.cmd)
    if exitCode == 0:
      log.info fmt"✅: Success"
    else:
      log.info fmt"❌: Non-zero exit."
    return exitCode

  var cache = createCache(ls())
  var counter = 0

  while true:
    if counter mod 10 == 0:
      var update = newFiles(cache, ls())
      for (f, t) in update.updates:
        log.info fmt"🐣: '{f}')"
        cache[f] = t
    var fastUpdate = hasChanged(cache)
    if len(fastUpdate.updates) > 0:
      for (f, t) in fastUpdate.updates:
        cache[f] = t
        log.info fmt"🧨: '{f}'"
      discard run()
    for f in fastUpdate.removed:
      del(cache, f)
      log.info fmt"🗑️ : '{f}'"

    inc(counter)
    sleep 100
