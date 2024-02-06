version = "0.1.0"
author = "nim-json authors"
description = "tests for nim-json library"
license = "MIT"

requires "asynctest >= 0.5.1 & < 0.6.0"
requires "questionable >= 0.10.13 & < 0.11.0"

task test, "Run the test suite":
  exec "nimble install -d -y"
  exec "nim c -r test"
