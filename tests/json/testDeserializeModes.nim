import std/options
import std/unittest

import pkg/stint
import pkg/serde
import pkg/questionable
import pkg/questionable/results

suite "json deserialization, mode = OptIn":

  test "deserializes only fields marked as deserialize when mode is OptIn":
    type MyObj {.deserialize(mode=OptIn).} = object
      field1: int
      field2 {.deserialize.}: bool

    let val = !MyObj.fromJson("""{"field1":true,"field2":true}""")
    check val == MyObj(field1: 0, field2: true)

  test "deserializes Optional fields when mode is OptIn":
    type MyObj {.deserialize(mode=OptIn).} = object
      field1 {.deserialize.}: bool
      field2 {.deserialize.}: Option[bool]

    let val = !MyObj.fromJson("""{"field1":true}""")
    check val == MyObj(field1: true, field2: none bool)


suite "json deserialization, mode = OptOut":

  test "deserializes object in OptOut mode when not marked with deserialize":
    type MyObj = object
      field1: bool
      field2: bool

    let val = !MyObj.fromJson("""{"field1":true,"field3":true}""")
    check val == MyObj(field1: true, field2: false)

  test "deserializes object field with marked json key":
    type MyObj = object
      field1 {.deserialize("test").}: bool
      field2: bool

    let val = !MyObj.fromJson("""{"test":true,"field2":true}""")
    check val == MyObj(field1: true, field2: true)

  test "fails to deserialize object field with wrong type":
    type MyObj = object
      field1: int
      field2: bool

    let r = MyObj.fromJson("""{"field1":true,"field2":true}""")
    check r.isFailure
    check r.error of UnexpectedKindError
    check r.error.msg == "deserialization to int failed: expected {JInt} but got JBool"

  test "does not deserialize ignored fields in OptOut mode":
    type MyObj = object
      field1 {.deserialize(ignore=true).}: bool
      field2: bool

    let val = !MyObj.fromJson("""{"field1":true,"field2":true}""")
    check val == MyObj(field1: false, field2: true)

  test "deserializes fields when marked with deserialize but not ignored":
    type MyObj = object
      field1 {.deserialize.}: bool
      field2: bool

    let val = !MyObj.fromJson("""{"field1":true,"field2":true}""")
    check val == MyObj(field1: true, field2: true)

  test "deserializes Optional field":
    type MyObj = object
      field1: Option[bool]
      field2: bool

    let val = !MyObj.fromJson("""{"field2":true}""")
    check val == MyObj(field1: none bool, field2: true)


suite "json deserialization, mode = Strict":

  test "deserializes matching object and json fields when mode is Strict":
    type MyObj {.deserialize(mode=Strict).} = object
      field1: bool
      field2: bool

    let val = !MyObj.fromJson("""{"field1":true,"field2":true}""")
    check val == MyObj(field1: true, field2: true)

  test "fails to deserialize with missing json field when mode is Strict":
    type MyObj {.deserialize(mode=Strict).} = object
      field1: bool
      field2: bool

    let r = MyObj.fromJson("""{"field2":true}""")
    check r.isFailure
    check r.error of SerdeError
    check r.error.msg == "object field missing in json: field1"

  test "fails to deserialize with missing object field when mode is Strict":
    type MyObj {.deserialize(mode=Strict).} = object
      field2: bool

    let r = MyObj.fromJson("""{"field1":true,"field2":true}""")
    check r.isFailure
    check r.error of SerdeError
    check r.error.msg == "json field(s) missing in object: {\"field1\"}"

  test "deserializes ignored fields in Strict mode":
    type MyObj {.deserialize(mode=Strict).} = object
      field1 {.deserialize(ignore=true).}: bool
      field2: bool

    let val = !MyObj.fromJson("""{"field1":true,"field2":true}""")
    check val == MyObj(field1: true, field2: true)
