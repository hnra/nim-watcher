import std/[os, osproc, parseopt, times, tables, strformat, strutils, options]

import globber/globber

type
  ProgramArgs* = object
    verbose*: bool
    cmd*: string
    glob*: string
    injectFile*: bool
    leadingEdge*: bool
    silentSuccess*: bool

const helpText = """
usage: watcher [--help[=argument]] [--verbose] [--glob=<glob>] [--inject]
               [--leading-edge[=false]] [--silent-succes]
               <command>

Most arguments can also be supplied as:
  -a, --a, -argument, or --argument.
If the argument takes a value it can be supplied with either "=" or ":".
"""

proc help(cmd: string) =
  case cmd:
  of "g", "glob":
    echo fmt"""
watcher --glob=<glob> <command>
  Runs <command> whenever a file which matches <glob> is changed.
  <glob> is a path with wildcards: .., *, or **.

Example:
  watcher --glob="**{DirSep}*.py" <command>
  <command> runs whenever a .py file in the current directory tree changes.
"""
  of "i", "inject-file":
    echo """
watcher --inject-file <command>
  Injects the full path of the file whose modification was detected.
  The path is injected at "{}" in the command (use \ to escape { or }).
  --inject-file implies --leading-edge=false.

Example:
  watcher --inject-file echo {}
  Will run "echo <path-to-file>" whenever <path-to-file> changes.
"""
  of "l", "leading-edge":
    echo """
watcher --leading-edge <command>
  Causes <command> to run on startup. This is the default behavior unless
  --inject-file is given.
watcher --leading-edge=false <command>
  Disables <command> being run on startup. Default if --inject-file is given.
"""
  else:
    echo helpText

proc parseArgs*(args: seq[string]): Option[ProgramArgs] =
  ## Parses the command line arguments into a `ProgramArgs` object.

  var glob = fmt"**{DirSep}*.nim"
  var cmd = ""
  var verbose = false
  var injectFile = false
  var leadingEdge = true
  var leadingEdgeForce = false
  var silentSuccess = false

  var p = initOptParser(args)
  while true:
    p.next()
    case p.kind:
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key:
      of "h", "help":
        help(p.val)
        return none(ProgramArgs)
      of "g", "glob":
        glob = p.val
      of "v", "verbose":
        verbose = true
      of "i", "inject":
        injectFile = true
        if not leadingEdgeForce:
          leadingEdge = false
      of "l", "leading-edge":
        if p.val == "false":
          leadingEdge = false
        else:
          leadingEdge = true
          leadingEdgeForce = true
      of "s", "silent-success":
        silentSuccess = true
      else: discard
    of cmdArgument:
      if cmd == "":
        cmd = p.key
      else:
        cmd &= " " & p.key

  return some(ProgramArgs(verbose: verbose, cmd: cmd, glob: glob, injectFile: injectFile, leadingEdge: leadingEdge, silentSuccess: silentSuccess))

type
  Log = proc (msg: string)
  Level = enum info, warning, error, console
  Logger = object
    info*: Log
    warning*: Log
    error*: Log
    console*: Log

proc createLogger(verbose: bool): Logger =
  proc log(level: Level): proc (msg:string): void =
    proc log(msg: string): void =
      case level:
      of info:
        if verbose:
          echo(msg)
      of console, warning, error:
        echo(msg)
    return log

  return Logger(info: log(info), warning: log(warning), error: log(error), console: log(console))

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
    if f.fileExists:
      let mtime = f.getlastmodificationtime
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
      let mtime = f.getlastmodificationtime
      updates.add((f, mtime))
  return CacheUpdate(removed: removed, updates: updates)

proc injectFileCmd*(cmd: string, file: string): string =
  var c = cmd.replace("{}", fmt"{file}")
  c = c.replace(r"\{", "{")
  c = c.replace(r"\}", "}")
  return c

proc main(): int =
  var args: ProgramArgs
  let oArgs = parseArgs(commandLineParams())
  if oArgs.isSome:
    args = oArgs.get()
  else:
    return 1

  let log = createLogger(args.verbose)

  proc ls(): seq[string] =
    return getCurrentDir().getFilesRecursive(args.glob)

  proc run(file: string): int =
    var cmd = args.cmd
    if args.injectFile:
      cmd = cmd.injectFileCmd(file)
    var exitCode = 0
    var cmdLog = log.info
    if args.silentSuccess:
      var (output, ec) = execCmdEx(cmd)
      exitCode = ec
      cmdLog = log.console
      if exitCode != 0:
        cmdLog output
    else:
      exitCode = execCmd(cmd)
    if exitCode == 0:
      cmdLog(fmt"✅: Success")
    else:
      cmdLog(fmt"❌: Non-zero exit.")
    return exitCode

  if args.leadingEdge:
    discard run("")

  var cache = ls().createCache
  var counter = 0

  while true:
    if counter mod 10 == 0:
      var update = cache.newFiles(ls())
      for (f, t) in update.updates:
        log.info fmt"🐣: '{f}')"
        cache[f] = t
      if len(update.updates) > 0:
        discard run(update.updates[0][0])
    var fastUpdate = cache.hasChanged
    if len(fastUpdate.updates) > 0:
      for (f, t) in fastUpdate.updates:
        cache[f] = t
        log.info fmt"🧨: '{f}'"
        discard run(f)
    for f in fastUpdate.removed:
      del(cache, f)
      log.info fmt"🗑️ : '{f}'"

    inc(counter)
    sleep 100

  return 0


when isMainModule:
  discard main()

