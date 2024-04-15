import std / [strutils, os]
import cligen

const
  ext = ".prf"
  illegalChars = ['\\', '/', ' ', '"', '\'']

var
  cfgPath: string
  cfgDir: string

template ee(msg: string) =
  stderr.writeLine msg

template prompt(msg: string, newline = true): string =
  stderr.write msg & (if newline: "\n" else: " ")
  stdin.readLine()

template err(msg: string, code: int) =
  ee msg
  return code

proc newProfile(set = false; profiles: seq[string]): int =
  if profiles.len == 0:
    err("command `new` requires one or more profile names", 1)
  var f: File
  for prf in profiles:
    let dest = cfgDir & "/" & prf & ext
    if fileExists(dest):
      ee "profile already exists: " & prf
    elif open(f, dest, fmWrite):
      defer: close f
      if set:
        let
          n = prompt "enter user.name for profile:"
          e = prompt "enter user.email for profile:"
        f.writeLine "[user]\n\tname = " & n & "\n\temail = " & e
    else:
      ee "could not create profile: " & prf

proc clone(args: seq[string]): int =
  if args.len == 0 or args.len > 2:
    err("command `clone` requires a destination profile or a source profile and destination profile", 1)
  let
    dest = cfgDir & "/" & args[^1] & ext
    src =
      if args.len == 2:
        cfgDir & "/" & args[0] & ext
      else:
        expandSymlink(cfgPath)
  if not fileExists(src):
    err("source profile not found", 1)
  elif fileExists(dest):
    err("destination profile already exists", 1)
  else:
    try:
      copyFile(src, dest)
    except Exception as e:
      ee "failed to clone profile: " & e.msg

proc become(profile: seq[string]): int =
  if profile.len != 1:
    err("command `become` requires one profile", 1)
  let src = cfgDir & "/" & profile[0] & ext
  if not fileExists(src):
    err("no such profile: " & profile[0], 1)
  removeFile(cfgPath)
  createSymlink(src, cfgPath)

proc remove(force = false; profiles: seq[string]): int =
  if profiles.len == 0:
    err("command `remove` requires one or more profile names", 1)
  for prf in profiles:
    let dest = cfgDir & "/" & prf & ext
    if dest == expandSymlink(cfgPath):
      ee "cannot remove profile in use"
      result = 1
      continue
    if not force:
      case prompt("removing profile '" & prf & "', continue? [y/N]", false)
      of "y", "Y":
        discard
      else:
        result = 1
        continue
    removeFile(dest)

proc status(verbose = false): int =
  let current = expandSymlink(cfgPath)
  echo "profile: " & splitFile(current).name
  if verbose:
    echo "symlink: " & cfgPath
    var f: File
    if open(f, current, fmRead):
      echo "source: " & current
      var line: string
      while f.readLine(line):
        echo "  " & line
    close f
    if fileExists(".git/config"):
      echo "\nrepository .git/config:"
      if open(f, ".git/config", fmRead):
        var line: string
        while f.readLine(line):
          echo "  " & line
      close f

proc list(): int =
  let current = expandSymlink(cfgPath)
  for f in walkDir(cfgDir, skipSpecial = true):
    if f.path.endsWith(ext):
      echo (if current == f.path:
        "* "
      else:
        "  ") & splitFile(f.path).name

proc setCfgDir(): bool =
  if existsEnv("XDG_CONFIG_HOME"):
    cfgDir = getEnv("XDG_CONFIG_HOME") & "/git"
  else:
    cfgDir = getEnv("HOME") & "/.dira"
  try:
    discard existsOrCreateDir(cfgDir)
    result = true
  except OSError:
    discard

proc setCfgPath() =
  cfgPath =
    if fileExists(getEnv("HOME") & "/.gitconfig"):
      getEnv("HOME") & "/.gitconfig"
    else:
      getEnv("XDG_CONFIG_HOME") & "/git/config"

proc checkProfile(input: seq[string] = @[]): bool =
  ## Check that config file is a symlink we control or offer to convert to
  ## profile if possible.
  let info = getFileInfo(cfgPath, false)
  if info.kind == pcFile:
    when not defined(release):
      let confirm =
        if input.len > 0:
          input[0]
        else:
          prompt("a git config already exists, do you want to convert it to a dira profile? [y/N]", false)
    else:
      let confirm = prompt("a git config already exists, do you want to convert it to a dira profile? [y/N]", false)
    case confirm
    of "y", "Y":
      discard
    else:
      return false
    when not defined(release):
      let prf =
        if input.len > 1:
          input[1]
        else:
          prompt "enter name for the new profile:"
    else:
      let prf = prompt "enter name for the new profile:"
    for c in illegalChars:
      if c in prf:
        ee "profile name cannot contain '" & illegalChars.join("', '") & "'"
        return false
    let ppath = cfgDir & "/" & prf & ext
    if fileExists(ppath):
      ee "profile already exists"
      return false
    moveFile(cfgPath, ppath)
    createSymlink(ppath, cfgPath)
    ee "old git config is now located at " & ppath
    result = true
  elif info.kind == pcLinkToFile or info.kind == pcLinkToDir:
    let x = expandFilename(cfgPath)
    if info.kind == pcLinkToDir:
      ee "git config is a symlink to a directory: " & cfgPath & " -> " & x
    elif parentDir(x) != cfgDir:
      ee "git config is a symlink but points to a different place: " & cfgPath & " -> " & x
    else:
      result = true
  else:
    ee "git config is a directory"

when isMainModule:
  if not setCfgDir():
    ee "config directory does not exists and could not be created: " & cfgDir
    ee "does parent directory " & parentDir(cfgDir) & " exist?"
    quit(1)
  setCfgPath()

  if not checkProfile():
    quit(1)

  const
    progName = "dira"
    progVer {.strdefine.} = strip(gorge("git tag -l --sort=version:refname '*.*.*' | tail -n1"))
    progUse = """
Usage:
  $1 [optional-params] subcommand
$$doc
Subcommands:
$$subcmds""" % [progName]

  clCfg.version = progVer

  proc subCmdUsage(cmd, params: string): string =
    result = progName & " " & cmd & " [optional-params] " & params &
            "\n${doc}Options(opt-arg sep :|=|spc):\n$options"

  dispatchMulti(
    [
      "multi", usage=progUse,
      doc="Manage git profiles through symlinks.",
      cf=clCfg
    ],
    [
      newProfile, cmdName="new",
      usage=subCmdUsage("new", "profiles..."),
      doc="Create a new profile.",
      help={
        "set": "set git config options for the profile after creation"
      },
      cf=clCfg
    ],
    [
      clone,
      usage=subCmdUsage("clone", "[src] dest"),
      doc="Clone profile.",
      cf=clCfg
    ],
    [
      become,
      usage=subCmdUsage("become", "profile"),
      doc="Switch profile.",
      cf=clCfg
    ],
    [
      remove,
      usage=subCmdUsage("remove", "profile..."),
      doc="Permanently remove profile.",
      help={
        "force": "do not ask for confirmation",
      },
      cf=clCfg
    ],
    [
      status,
      usage=subCmdUsage("status", ""),
      doc="Show current profile and mask.",
      help={
        "verbose": "print setup details and current config",
      },
      cf=clCfg
    ],
    [
      list,
      usage=subCmdUsage("list", ""),
      doc="List available profiles.",
      cf=clCfg
    ],
  )
