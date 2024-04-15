import std / [os, unittest]
import dira {.all.}

const
  xdgPath = parentDir(currentSourcePath()) & "/xdg"
  homePath = parentDir(currentSourcePath()) & "/home"

suite "set cfgDir and cfgPath":

  setup:
    removeDir(xdgPath)
    removeDir(homePath)
    delEnv("XDG_CONFIG_HOME")
    putEnv("HOME", homePath)

  teardown:
    removeDir(xdgPath)
    removeDir(homePath)
    delEnv("XDG_CONFIG_HOME")
    cfgDir = ""
    cfgPath = ""

  test "XDG_CONFIG_HOME":
    putEnv("XDG_CONFIG_HOME", xdgPath)
    let env = getenv("XDG_CONFIG_HOME")
    echo env
    check(not setCfgDir())
    createDir(xdgPath)
    check(setCfgDir())
    echo cfgDir
    check(env == xdgPath)
    setCfgPath()
    echo cfgPath

  test "HOME":
    let env = getenv("HOME")
    echo env
    check(not setCfgDir())
    createDir(homePath)
    check(setCfgDir())
    echo cfgDir
    check(env == homePath)
    var f = open(env & "/.gitconfig", fmWrite)
    defer: close f
    setCfgPath()
    let x = parentDir(cfgPath)
    check(env == x)

