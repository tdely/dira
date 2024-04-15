import std / [os, unittest]
import dira {.all.}
from cligen import HelpError

suite "command tests":

  cfgDir = parentDir(currentSourcePath()) & "/profiles"
  cfgPath = parentDir(currentSourcePath()) & "/current"
  let
    p1 = cfgDir & "/one" & ext
    p2 = cfgDir & "/two" & ext

  setup:
    createDir(cfgDir)
    var f = open(p1, fmWrite)
    f.write("""[user]
	name = etienne steward
	email = none
[core]
	editor = mc
""")
    close f
    f = open(p2, fmWrite)
    f.write("""[user]
	name = guildenstern
	email = none
[core]
	editor = mc
""")
    close f
    createSymlink(p2, cfgPath)

  teardown:
    removeDir(cfgDir)
    removeFile(cfgPath)

  test "list":
    check(list() == 0)

  test "status":
    check(status() == 0)

  test "status verbose":
    check(status(true) == 0)

  test "new":
    check(newProfile(false, @["drei"]) == 0)
    check(fileExists(cfgDir & "/drei" & ext))

  test "new multiple":
    check(newProfile(false, @["two", "three", "four"]) == 0)
    check(fileExists(cfgDir & "/three" & ext))
    check(fileExists(cfgDir & "/four" & ext))

  test "new too few args":
    expect HelpError:
      discard newProfile(false, @[])

  test "clone":
    check(clone(@["one", "dup"]) == 0)
    check(fileExists(cfgDir & "/dup" & ext))
    # todo: open one, write line, duplicate, open dup, verify line

  test "clone implicit src":
    check(clone(@["dup"]) == 0)
    check(fileExists(cfgDir & "/dup" & ext))
    # todo: open current, write line, duplicate, open dup, verify line

  test "clone conflict":
    check(clone(@["one", "two"]) == 1)

  test "clone src missing":
    check(clone(@["miss", "dup"]) == 1)

  test "clone too few and too many args":
    expect HelpError:
      discard clone(@[])
    expect HelpError:
      discard clone(@["a", "b", "c"])

  test "remove":
    check(remove(true, @["one"]) == 0)
    check(not fileExists(p1))
    check(fileExists(p2))

  test "remove current":
    check(remove(true, @["two"]) == 1)
    check(fileExists(p1))
    check(fileExists(p2))

  test "remove multiple":
    check(remove(true, @["one", "two"]) == 1)
    check(not fileExists(p1))
    check(fileExists(p2))
