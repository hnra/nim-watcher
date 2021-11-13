import std/[unittest, strformat, strutils]

import ../src/watcher

test "globArg":
  let glob = "**/*.nim"
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
  check pargs.verbose

test "injectArg":
  let pargs = parseArgs(split("-i cmd {}"))
  check pargs.cmd == "cmd {}"
  check pargs.injectFile
  check injectFileCmd(pargs.cmd, "") == "cmd "
  check injectFileCmd(pargs.cmd, "foo.nim") == "cmd foo.nim"

test "file is injected":
  check injectFileCmd("echo {}", "hello.nim") == "echo hello.nim"

test "missing file gives valid command":
  check injectFileCmd("echo {}", "") == "echo "

test "escaped cmd":
  check injectFileCmd(r"echo {} \{\}", "hello.nim") == "echo hello.nim {}"
  check injectFileCmd(r"echo {} \\{\\}", "hello.nim") == r"echo hello.nim \{\}"

test "missing inject points gives valid command":
  check injectFileCmd("echo foo.nim", "bar.nim") == "echo foo.nim"

