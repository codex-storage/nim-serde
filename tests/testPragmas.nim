import std/math
import std/options
import std/strformat
import std/strutils
import std/unittest

import pkg/serde
import pkg/stew/byteutils
import pkg/stint
import pkg/questionable
import pkg/questionable/results

suite "json serialization pragmas":

  test "fails to compile when object marked with 'serialize' specifies options":
    type
      MyObj {.serialize(key="test", ignore=true).} = object

    check not compiles(%MyObj())

  test "compiles when object marked with 'serialize' only":
    type
      MyObj {.serialize.} = object

    check compiles(%MyObj())

  test "fails to compile when field marked with 'deserialize' specifies mode":
    type
      MyObj = object
       field {.deserialize(mode=OptIn).}: bool

    check not compiles(MyObj.fromJson("""{"field":true}"""))

  test "compiles when object marked with 'deserialize' specifies mode":
    type
      MyObj {.deserialize(mode=OptIn).} = object
       field: bool

    check compiles(MyObj.fromJson("""{"field":true}"""))

  test "fails to compile when object marked with 'deserialize' specifies key":
    type
      MyObj {.deserialize("test").} = object
       field: bool

    check not compiles(MyObj.fromJson("""{"field":true}"""))

  test "compiles when field marked with 'deserialize' specifies key":
    type
      MyObj = object
       field {.deserialize("test").}: bool

    check compiles(MyObj.fromJson("""{"field":true}"""))

  test "compiles when field marked with empty 'deserialize'":
    type
      MyObj = object
       field {.deserialize.}: bool

    check compiles(MyObj.fromJson("""{"field":true}"""))

  test "compiles when field marked with 'serialize'":
    type
      MyObj = object
        field {.serialize.}: bool

    check compiles(%MyObj())