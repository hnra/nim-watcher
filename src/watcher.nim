import std/[os, osproc, parseopt, times, tables, strformat]

import globber/globber

type
  ProgramArgs* = object
    log*: proc (msg: string): void
    cmd*: string
    glob*: string

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

  proc log(msg: string): void =
    if verbose:
      echo(msg)

  assert watchCmd != ""

  return ProgramArgs(log: log, cmd: watchCmd, glob: watchGlob)

when isMainModule:
  let args = parseArgs(commandLineParams())

  proc ls(): seq[string] =
    return getFilesRecursive(getCurrentDir() , args.glob)

  proc run(): void =
    args.log fmt"👟: Running"
    let exitCode = execCmd(args.cmd)
    if exitCode == 0:
      args.log fmt"✅: Success"
    else:
      args.log fmt"❌: Non-zero exit."

  proc createCache(): TableRef[string, Time] =
    var cache = newTable[string, Time]()

    for f in ls():
      let mtime = getLastModificationTime f
      cache[f] = mtime
      args.log fmt"🐝: '{f}'"

    return cache

  var cache = createCache()

  proc hasChangedFast(): bool =
    var removedFiles = newSeq[string]()
    for f, t in cache.pairs:
      if fileExists(f):
        let mtime = getlastmodificationtime f
        if mtime > t:
          args.log fmt"🧨: '{f}'"
          cache[f] = mtime
          return true
      else:
        removedFiles.add(f)
    for f in removedFiles:
      args.log fmt"🗑️ : '{f}'"
      del(cache, f)

  proc hasChanged(): bool =
    var changed = false
    for f in ls():
      let mtime = getlastmodificationtime f
      if f in cache:
        if mtime > cache[f]:
          args.log fmt"🧨: '{f}'"
          cache[f] = mtime
          changed = true
      else:
        args.log fmt"🐣: '{f}')"
        cache[f] = mtime
        changed = true
    return changed

  var counter = 0

  while true:
    if counter mod 10 == 0:
      if hasChanged():
        run()
    else:
      if hasChangedFast():
        run()
    inc(counter)
    sleep 100

