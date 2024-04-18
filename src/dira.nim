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

template prompt(msg: string): string =
  stderr.write msg & " "
  stdin.readLine()

template err(msg: string, code: int) =
  ee msg
  return code

proc newProfile(become = false; set = false; profiles: seq[string]): int =
  if profiles.len == 0:
    err("command `new` requires one or more profile names", 1)
  var
    f: File
    cfg: string
  for prf in profiles:
    let dest = cfgDir & "/" & prf & ext
    if fileExists(dest):
      ee "profile already exists: " & prf
      continue
    if set:
      ee "setting up profile, leave empty to skip"
      for x in [(section: "user", keys: @["name", "email"]), (section: "core", keys: @["editor"])]:
        cfg.add "[" & x.section & "]\n"
        for key in x.keys:
          let val = prompt x.section & "." & key & ":"
          if val.len > 0:
            cfg.add "\t" & key & " = " & val & "\n"

    if open(f, dest, fmWrite):
      defer: close f
      if set:
        f.write cfg
    else:
      err("could not create profile: " & prf, 1)
  if become:
    if profiles.len > 1:
      ee "more than one profile was created, ignoring --become"
    else:
      removeFile(cfgPath)
      createSymlink(cfgDir & "/" & profiles[0] & ext, cfgPath)
      echo "active profile is now " & profiles[0]

proc clone(become = false; args: seq[string]): int =
  if args.len == 0 or args.len > 2:
    err("command `clone` requires a destination profile or a source profile and destination profile", 1)
  let
    dest = cfgDir & "/" & args[^1] & ext
    src =
      if args.len == 2:
        cfgDir & "/" & args[0] & ext
      else:
        try:
          expandSymlink(cfgPath)
        except OSError:
          err("could not determine active profile", 1)
  if not fileExists(src):
    err("source profile not found", 1)
  elif fileExists(dest):
    err("destination profile already exists", 1)
  else:
    try:
      copyFile(src, dest)
      if become:
        removeFile(cfgPath)
        createSymlink(dest, cfgPath)
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
    if not fileExists(dest):
      continue
    try:
      if dest == expandSymlink(cfgPath):
        ee "cannot remove profile in use"
        result = 1
        continue
    except OSError:
      discard
    if not force:
      case prompt "removing profile '" & prf & "', continue? [y/N]"
      of "y", "Y":
        discard
      else:
        result = 1
        continue
    removeFile(dest)

proc show(profile: seq[string]): int =
  if profile.len > 1:
    err("command `show` accepts at most one profile", 1)
  let prf =
    if profile.len == 0:
      try:
        expandSymlink(cfgPath)
      except OSError:
        err("could not determine active profile", 1)
    else:
      cfgDir & "/" & profile[0] & ext
  var f: File
  if open(f, prf, fmRead):
    defer: close f
    var line: string
    while f.readLine(line):
      echo line
  else:
    err("failed to open profile, are you sure it exists?", 1)

proc status(verbose = false): int =
  var current: string
  try:
    current = expandSymlink(cfgPath)
  except OSError:
    err("could not determine active profile", 1)
  echo "profile: " & splitFile(current).name
  if verbose:
    echo "symlink: " & cfgPath
    var f: File
    if open(f, current, fmRead):
      defer: close f
      echo "source: " & current
      var line: string
      while f.readLine(line):
        echo "  " & line
    if fileExists(".git/config"):
      echo "\nrepository .git/config:"
      if open(f, ".git/config", fmRead):
        defer: close f
        var line: string
        while f.readLine(line):
          echo "  " & line

proc list(): int =
  let current =
    try:
      expandSymlink(cfgPath)
    except OSError:
      ""
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
          prompt "a git config already exists, do you want to convert it to a dira profile? [y/N]"
    else:
      let confirm = prompt "a git config already exists, do you want to convert it to a dira profile? [y/N]"
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
        "become": "switch to new profile, ignored if multiple profiles given",
        "set": "set git config options for the profile after creation"
      },
      cf=clCfg
    ],
    [
      clone,
      usage=subCmdUsage("clone", "[src] dest"),
      doc="Clone profile.",
      help={
        "become": "switch to new profile",
      },
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
      show,
      usage=subCmdUsage("show", "[profile]"),
      doc="Show profile config.",
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
