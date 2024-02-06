# Package

version       = "0.1.0"
author        = "nim-json authors"
description   = "Drop-in replacement for std/json, with easy-to-use json serialization capabilities."
license       = "MIT"
srcDir        = "src"


# Dependencies
requires "nim >= 1.6.14"
requires "chronicles >= 0.10.3 & < 0.11.0"
requires "questionable >= 0.10.13 & < 0.11.0"
requires "stint"
requires "stew"

task test, "Run the test suite":
  exec "nimble install -d -y"
  withDir "tests":
    exec "nimble test"
