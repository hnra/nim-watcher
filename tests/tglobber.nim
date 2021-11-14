import std/[strutils, strformat, os, sequtils, unittest, re]

import ../src/globber/globber

when defined(posix):
  test "pathParts (POSIX)":
    check pathParts("/bin/bash") == @["/", "bin", "bash"]
    check pathParts("/bin/bash/") == @["/", "bin", "bash"]
    check pathParts("bin/bash") == @["bin", "bash"]
    check pathParts("") == newSeq[string]()
    check pathParts("**/.*") == @["**", ".*"]
    check pathParts("/**/.*") == @["/", "**", ".*"]

when defined(windows):
  test "pathParts (Windows)":
    check pathParts(r"C:\bin\bash") == @["C:", "bin", "bash"]

test "splitAt":
  check splitAt(( proc (x: int): bool = x > 5 ), toSeq 1..10) == (toSeq 1..5, toSeq 6..10)
  check splitAt(( proc (p: string): bool = p == "**" ), @["/", "bin", "**", "foo"]) == (@["/", "bin"], @["**", "foo"])

const sep = $DirSep
let repo = getCurrentDir()

proc hasFile(files: seq[string], file: string): bool =
  any(files, proc (s: string): bool = endsWith(s, sep / file))

proc allExtensions(files: seq[string], ext: string): bool =
  all(files, proc (s: string): bool = endsWith(s, ext))

test "globber.nim finds file":
  let files = getFilesRecursive(repo / "src" / "globber", "globber.nim")
  check hasFile(files, "globber.nim")
  check not hasFile(files, "tglobber.nim")
  check allExtensions(files, ".nim")

test "*.nim glob finds no src/test files":
  let files = getFilesRecursive(repo, "*.nim")
  check not hasFile(files, "globber.nim")
  check not hasFile(files, "tglobber.nim")
  check allExtensions(files, ".nim")

test "src/* glob finds src files":
  let files = getFilesRecursive(repo, "src" / "*.nim")
  check hasFile(files, "watcher.nim")
  check not hasFile(files, "globber.nim")
  check not hasFile(files, "tglobber.nim")
  check allExtensions(files, ".nim")

test "**/ glob finds all files":
  let files = getFilesRecursive(repo, "**" / "*.nim")
  check hasFile(files, "globber.nim")
  check hasFile(files, "tglobber.nim")
  check allExtensions(files, ".nim")

test "**/** star glob finds all files":
  let files = getFilesRecursive(repo, "**" / "**" / "*.nim")
  check hasFile(files, "globber.nim")
  check hasFile(files, "tglobber.nim")
  check allExtensions(files, ".nim")

test "src/** glob fins src files":
  let files = getFilesRecursive(repo, "src" / "**" / "*.nim")
  check hasFile(files, "globber.nim")
  check not hasFile(files, "tglobber.nim")
  check allExtensions(files, ".nim")

test "../** glob finds all files":
  let files = getFilesRecursive(repo / "src", ".." / "**" / "*.nim")
  check hasFile(files, "globber.nim")
  check hasFile(files, "tglobber.nim")
  check allExtensions(files, ".nim")

test "../tests glob finds test files":
  let files = getFilesRecursive(repo / "src", ".." / "tests" / "*.nim")
  check not hasFile(files, "globber.nim")
  check hasFile(files, "tglobber.nim")
  check allExtensions(files, ".nim")

