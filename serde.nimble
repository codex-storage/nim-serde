# Package

version = "1.2.2"
author = "nim-serde authors"
description = "Easy-to-use serialization capabilities (currently json only)."
license = "MIT"
skipDirs = @["tests"]

# Dependencies
requires "chronicles >= 0.10.3"
requires "questionable >= 0.10.13 & < 0.11.0"
requires "stint"
requires "stew"

task test, "Run the test suite":
  exec "nimble install -d -y"
  withDir "tests":
    exec "nimble test"
