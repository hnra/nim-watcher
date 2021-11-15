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
  check splitAt(proc (x: int): bool = x > 5, toSeq 1..10) == (toSeq 1..5, toSeq 6..10)
  check splitAt(proc (p: string): bool = p == "**", @["/", "bin", "**", "foo"]) == (@["/", "bin"], @["**", "foo"])

test "UNIX glob matches":
  const glob = "**/*.nim"
  const path1 = "a/b/c/foo.nim"
  const path2 = "a/b/c/foo.py"
  let pattern = re(globToPattern(glob, dirSep="/"))
  assert match(path1, pattern)
  assert not match(path2, pattern)

test "Windows glob matches":
  const glob = r"**\*.nim"
  const path1 = r"a\foo.nim"
  const path2 = r"a\foo.py"
  let pattern1 = re(globToPattern(glob, dirSep=r"\"))
  assert match(path1, pattern1)
  assert not match(path2, pattern1)

  const path3 = r"C:\a\foo.nim"
  const path4 = r"C:\a\foo.py"
  let pattern2 = re(globToPattern(glob, base=r"C:\", dirSep=r"\"))
  assert match(path3, pattern2)
  assert not match(path1, pattern2)
  assert not match(path2, pattern2)
  assert not match(path4, pattern2)

test "glob to pattern":
  const glob = "**/*.nim"
  const path1 = "a/b/c/foo.nim"
  const pattern = globToPattern(glob, dirSep="/")
  assert match(path1, re(pattern))

const sep = $DirSep
let repo = getCurrentDir()

proc hasFile(files: seq[string], file: string): bool =
  any(files, proc (s: string): bool = endsWith(s, sep / file))

proc allExtensions(files: seq[string], ext: string): bool =
  all(files, proc (s: string): bool = endsWith(s, ext))

test "globber.nim finds file":
  let files = getFilesRecursive(repo / "src" / "globber", "globber.nim")
  check files.hasFile("globber.nim")
  check not files.hasFile("tglobber.nim")
  check files.allExtensions(".nim")

test "*.nim glob finds no src/test files":
  let files = getFilesRecursive(repo, "*.nim")
  check not files.hasFile("globber.nim")
  check not files.hasFile("tglobber.nim")
  check files.allExtensions(".nim")

test "src/* glob finds src files":
  let files = getFilesRecursive(repo, "src" / "*.nim")
  check files.hasFile("watcher.nim")
  check not files.hasFile("globber.nim")
  check not files.hasFile("tglobber.nim")
  check files.allExtensions(".nim")

test "**/ glob finds all files":
  let files = getFilesRecursive(repo, "**" / "*.nim")
  check files.hasFile("globber.nim")
  check files.hasFile("tglobber.nim")
  check files.allExtensions(".nim")

test "**/** star glob finds all files":
  let files = getFilesRecursive(repo, "**" / "**" / "*.nim")
  check files.hasFile("globber.nim")
  check files.hasFile("tglobber.nim")
  check files.allExtensions(".nim")

test "src/** glob fins src files":
  let files = getFilesRecursive(repo, "src" / "**" / "*.nim")
  check files.hasFile("globber.nim")
  check not files.hasFile("tglobber.nim")
  check files.allExtensions(".nim")

test "../** glob finds all files":
  let files = getFilesRecursive(repo / "src", ".." / "**" / "*.nim")
  check files.hasFile("globber.nim")
  check files.hasFile("tglobber.nim")
  check files.allExtensions(".nim")

test "../tests glob finds test files":
  let files = getFilesRecursive(repo / "src", ".." / "tests" / "*.nim")
  check not files.hasFile("globber.nim")
  check files.hasFile("tglobber.nim")
  check files.allExtensions(".nim")

