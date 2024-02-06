import std/unittest

# import pkg/stint
import pkg/serde

suite "json serialization, mode = OptIn":

  test "serializes with default mode OptIn when object not marked with serialize":
    type MyObj = object
      field1 {.serialize.}: bool
      field2: bool

    let obj = MyObj(field1: true, field2: true)
    check obj.toJson == """{"field1":true}"""

  test "not marking object with serialize is equivalent to marking it with serialize in OptIn mode":
    type MyObj = object
      field1 {.serialize.}: bool
      field2: bool

    type MyObjMarked {.serialize(mode=OptIn).} = object
      field1 {.serialize.}: bool
      field2: bool

    let obj = MyObj(field1: true, field2: true)
    let objMarked = MyObjMarked(field1: true, field2: true)
    check obj.toJson == objMarked.toJson

  test "serializes field with key when specified":
    type MyObj = object
      field1 {.serialize("test").}: bool
      field2 {.serialize.}: bool

    let obj = MyObj(field1: true, field2: true)
    check obj.toJson == """{"test":true,"field2":true}"""

  test "does not serialize ignored field":
    type MyObj = object
      field1 {.serialize.}: bool
      field2 {.serialize(ignore=true).}: bool

    let obj = MyObj(field1: true, field2: true)
    check obj.toJson == """{"field1":true}"""


suite "json serialization, mode = OptOut":

  test "serialize on object definition defaults to OptOut mode, serializes all fields":
    type MyObj {.serialize.} = object
      field1: bool
      field2: bool

    let obj = MyObj(field1: true, field2: true)
    check obj.toJson == """{"field1":true,"field2":true}"""

  test "not specifying serialize mode is equivalent to specifying OptOut mode":
    type MyObj {.serialize.} = object
      field1: bool
      field2: bool

    type MyObjMarked {.serialize(mode=OptOut).} = object
      field1: bool
      field2: bool

    let obj = MyObj(field1: true, field2: true)
    let objMarked = MyObjMarked(field1: true, field2: true)
    check obj.toJson == objMarked.toJson

  test "ignores field when marked with ignore":
    type MyObj {.serialize.} = object
      field1 {.serialize(ignore=true).}: bool
      field2: bool

    let obj = MyObj(field1: true, field2: true)
    check obj.toJson == """{"field2":true}"""

  test "serializes field with key instead of field name":
    type MyObj {.serialize.} = object
      field1 {.serialize("test").}: bool
      field2: bool

    let obj = MyObj(field1: true, field2: true)
    check obj.toJson == """{"test":true,"field2":true}"""


suite "json serialization - mode = Strict":

  test "serializes all fields in Strict mode":
    type MyObj {.serialize(mode=Strict).} = object
      field1: bool
      field2: bool

    let obj = MyObj(field1: true, field2: true)
    check obj.toJson == """{"field1":true,"field2":true}"""

  test "ignores ignored fields in Strict mode":
    type MyObj {.serialize(mode=Strict).} = object
      field1 {.serialize(ignore=true).}: bool
      field2: bool

    let obj = MyObj(field1: true, field2: true)
    check obj.toJson == """{"field1":true,"field2":true}"""
