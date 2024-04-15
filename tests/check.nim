import std / [os, unittest]
import dira {.all.}

suite "checkProfile":

  cfgDir = parentDir(currentSourcePath())
  cfgPath = cfgDir & "/config"

  test "conflict with directory":
    createDir(cfgPath)
    defer: removeDir(cfgPath)
    check(not checkProfile())

  test "conflict with symlink to directory":
    let dir = cfgDir & "/eee"
    createDir(dir)
    defer: removeDir(dir)
    createSymlink(dir, cfgPath)
    defer: removeFile(cfgPath)
    check(not checkProfile())

  test "conflict with symlink to other file":
    let
      fp = cfgDir & "/../eee"
      f = open(fp, fmWrite)
    defer:
      close f
      removeFile(fp)
    createSymlink(fp, cfgPath)
    defer: removeFile(cfgPath)
    check(not checkProfile())

  test "already symlink to profile":
    let
      fp = cfgDir & "/eee"
      f = open(fp, fmWrite)
    defer:
      close f
      removeFile(fp)
    createSymlink(fp, cfgPath)
    defer: removeFile(cfgPath)
    check(checkProfile(@["n"]))

  test "convert config to profile":
    let f = open(cfgPath, fmWrite)
    defer:
      close f
      removeFile(cfgPath)
      removeFile(cfgDir & "/test.prf")
    check(checkProfile(@["y", "test"]))

  test "do not convert config":
    let f = open(cfgPath, fmWrite)
    defer:
      close f
      removeFile(cfgPath)
      removeFile(cfgDir & "/test.prf")
    check(not checkProfile(@["n", "test"]))

  test "convert config conflict":
    let
      f = open(cfgPath, fmWrite)
      f2 = open(cfgDir & "/test.prf", fmWrite)
    defer:
      close f
      close f2
      removeFile(cfgPath)
      removeFile(cfgDir & "/test.prf")
    check(not checkProfile(@["y", "test"]))

  cfgDir = ""
  cfgPath = ""
