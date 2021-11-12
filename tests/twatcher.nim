import std/[unittest, strformat, strutils]

import ../src/watcher

test "globArg":
  let glob = "**/*.py"
  let args = @[fmt"-g={glob}", "cmd"]
  let pargs = parseArgs(args)
  check pargs.glob == glob

test "cmdArg":
  let cmd = "echo \"hello\""
  let args = split(cmd, " ")
  let pargs = parseArgs(args)
  check pargs.cmd == "echo \"hello\""

test "verboseArg":
  let pargs = parseArgs(split("-v cmd"))
  check pargs.cmd == "cmd"

