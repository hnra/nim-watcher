# nim-watcher

**A file watcher written in Nim.**

For more info:
```
watcher -h
```

## Examples

Say hello whenever a Nim file in the current directory tree changes:
```
watcher echo hello
```

Compile and run a Nim file if it changes:
```
watcher --inject-file "nim c -r {}"
```

Run Python whenever a Python file changes:
```
watcher --inject-file --glob="**/*.py" "python {}"
```

