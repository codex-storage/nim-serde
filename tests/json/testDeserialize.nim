import std/math
import std/options
import std/unittest
import pkg/stint
import pkg/serde
import pkg/stew/byteutils
import pkg/questionable
import pkg/questionable/results

suite "json serialization - deserialize":
  test "deserializes NaN float":
    check %NaN == newJString("nan")

  test "deserialize enum":
    type MyEnum = enum
      First
      Second

    let json = newJString("Second")
    check !MyEnum.fromJson(json) == Second

  test "deserializes UInt256 from an empty string":
    let json = newJString("")
    check !UInt256.fromJson(json) == 0.u256

  test "deserializes UInt256 with no prefix":
    let json = newJString("1")
    check !UInt256.fromJson(json) == 1.u256

  test "deserializes UInt256 from hex string representation":
    let json = newJString("0x1")
    check !UInt256.fromJson(json) == 0x1.u256

  test "deserializes UInt256 from octal string representation":
    let json = newJString("0o1")
    check !UInt256.fromJson(json) == 0o1.u256

  test "deserializes UInt256 from binary string representation":
    let json = newJString("0b1")
    check !UInt256.fromJson(json) == 0b1.u256

  test "deserializes UInt256 from non-hex string representation":
    let json = newJString("100000")
    check !UInt256.fromJson(json) == 100000.u256

  test "deserializes Int256 with no prefix":
    let json = newJString("1")
    check !Int256.fromJson(json) == 1.i256

  test "deserializes Option[T] when has a value":
    let json = newJInt(1)
    check (!fromJson(?int, json) == some 1)

  test "deserializes Option[T] when doesn't have a value":
    let json = newJNull()
    check !fromJson(?int, json) == none int

  test "deserializes float":
    let json = newJFloat(1.234)
    check !float.fromJson(json) == 1.234

  test "deserializes Inf float":
    let json = newJString("inf")
    check !float.fromJson(json) == Inf

  test "deserializes -Inf float":
    let json = newJString("-inf")
    check !float.fromJson(json) == -Inf

  test "deserializes NaN float":
    let json = newJString("nan")
    check (!float.fromJson(json)).isNaN

  test "deserializes array to sequence":
    let expected = @[1, 2, 3]
    let json = !JsonNode.parse("[1,2,3]")
    check !seq[int].fromJson(json) == expected

  test "deserializes uints int.high or smaller":
    let largeUInt: uint = uint(int.high)
    let json = newJInt(BiggestInt(largeUInt))
    check !uint.fromJson(json) == largeUInt

  test "deserializes large uints":
    let largeUInt: uint = uint(int.high) + 1'u
    let json = newJString($BiggestUInt(largeUInt))
    check !uint.fromJson(json) == largeUInt

  test "can deserialize json objects":
    type MyObj = object
      mystring: string
      myint: int
      myoption: ?bool

    let expected = MyObj(mystring: "abc", myint: 123, myoption: some true)

    let json =
      !JsonNode.parse(
        """{
            "mystring": "abc",
            "myint": 123,
            "myoption": true
          }"""
      )

    check !MyObj.fromJson(json) == expected

  test "ignores serialize pragma when deserializing":
    type MyObj = object
      mystring {.serialize.}: string
      mybool: bool

    let expected = MyObj(mystring: "abc", mybool: true)

    let json =
      !JsonNode.parse(
        """{
            "mystring": "abc",
            "mybool": true
          }"""
      )

    check !MyObj.fromJson(json) == expected

  test "deserializes objects with extra fields":
    type MyObj = object
      mystring: string
      mybool: bool

    let expected = MyObj(mystring: "abc", mybool: true)

    let json =
      !JsonNode.parse(
        """{
            "mystring": "abc",
            "mybool": true,
            "extra": "extra"
          }"""
      )
    check !MyObj.fromJson(json) == expected

  test "deserializes objects with less fields":
    type MyObj = object
      mystring: string
      mybool: bool

    let expected = MyObj(mystring: "abc", mybool: false)

    let json =
      !JsonNode.parse(
        """{
            "mystring": "abc"
          }"""
      )
    check !MyObj.fromJson(json) == expected

  test "deserializes ref objects":
    type MyRef = ref object
      mystring: string
      myint: int

    let expected = MyRef(mystring: "abc", myint: 1)

    let json =
      !JsonNode.parse(
        """{
            "mystring": "abc",
            "myint": 1
          }"""
      )

    let deserialized = !MyRef.fromJson(json)
    check deserialized.mystring == expected.mystring
    check deserialized.myint == expected.myint

  test "deserializes openArray[byte]":
    type MyRef = ref object
      mystring: string
      myint: int

    let expected = MyRef(mystring: "abc", myint: 1)
    let byteArray = """{
            "mystring": "abc",
            "myint": 1
          }""".toBytes

    let deserialized = !MyRef.fromJson(byteArray)
    check deserialized.mystring == expected.mystring
    check deserialized.myint == expected.myint

suite "deserialize from string":

  test "deserializes objects from string":
    type MyObj = object
      mystring: string
      myint: int

    let expected = MyObj(mystring: "abc", myint: 1)
    let myObjJson = """{
            "mystring": "abc",
            "myint": 1
          }"""

    check !MyObj.fromJson(myObjJson) == expected

  test "deserializes ref objects from string":
    type MyRef = ref object
      mystring: string
      myint: int

    let expected = MyRef(mystring: "abc", myint: 1)
    let myRefJson = """{
            "mystring": "abc",
            "myint": 1
          }"""

    let deserialized = !MyRef.fromJson(myRefJson)
    check deserialized.mystring == expected.mystring
    check deserialized.myint == expected.myint

  test "deserializes seq[T] from string":
    type MyObj = object
      mystring: string
      myint: int

    let expected = @[MyObj(mystring: "abc", myint: 1)]
    let myObjsJson = """[{
            "mystring": "abc",
            "myint": 1
          }]"""

    check !seq[MyObj].fromJson(myObjsJson) == expected

  test "deserializes Option[T] from string":
    type MyObj = object
      mystring: string
      myint: int

    let expected = some MyObj(mystring: "abc", myint: 1)
    let myObjJson = """{
            "mystring": "abc",
            "myint": 1
          }"""

    check !(Option[MyObj].fromJson(myObjJson)) == expected
