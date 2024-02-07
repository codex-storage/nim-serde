import std/options
import std/strutils
import std/unittest
import pkg/stint
import pkg/serde
import pkg/questionable

import ../helpers

suite "json serialization - serialize":

  test "serializes UInt256 to non-hex string representation":
    check (% 100000.u256) == newJString("100000")

  test "serializes sequence to an array":
    let json = % @[1, 2, 3]
    let expected = "[1,2,3]"
    check $json == expected

  test "serializes Option[T] when has a value":
    let obj = %(some 1)
    let expected = "1"
    check $obj == expected

  test "serializes Option[T] when doesn't have a value":
    let obj = %(none int)
    let expected = "null"
    check $obj == expected

  test "serializes uints int.high or smaller":
    let largeUInt: uint = uint(int.high)
    check %largeUInt == newJInt(BiggestInt(largeUInt))

  test "serializes large uints":
    let largeUInt: uint = uint(int.high) + 1'u
    check %largeUInt == newJString($largeUInt)

  test "serializes Inf float":
    check %Inf == newJString("inf")

  test "serializes -Inf float":
    check %(-Inf) == newJString("-inf")

  test "can construct json objects with %*":
    type MyObj = object
      mystring {.serialize.}: string
      myint {.serialize.}: int
      myoption {.serialize.}: ?bool

    let myobj = MyObj(mystring: "abc", myint: 123, myoption: some true)
    let mystuint = 100000.u256

    let json = %*{
      "myobj": myobj,
      "mystuint": mystuint
    }

    let expected = """{
                        "myobj": {
                          "mystring": "abc",
                          "myint": 123,
                          "myoption": true
                        },
                        "mystuint": "100000"
                      }""".flatten

    check $json == expected

  test "only serializes marked fields":
    type MyObj = object
      mystring {.serialize.}: string
      myint {.serialize.}: int
      mybool: bool

    let obj = % MyObj(mystring: "abc", myint: 1, mybool: true)

    let expected = """{
                        "mystring": "abc",
                        "myint": 1
                      }""".flatten

    check $obj == expected

  test "serializes ref objects":
    type MyRef = ref object
      mystring {.serialize.}: string
      myint {.serialize.}: int

    let obj = % MyRef(mystring: "abc", myint: 1)

    let expected = """{
                        "mystring": "abc",
                        "myint": 1
                      }""".flatten

    check $obj == expected

  test "serializes to string with toJson":
    type MyObj = object
      mystring {.serialize.}: string
      myint {.serialize.}: int

    let obj = MyObj(mystring: "abc", myint: 1)
    let expected = """{"mystring":"abc","myint":1}"""

    check obj.toJson == expected

  test "serializes prettied to string with toJson":
    type MyObj = object
      mystring {.serialize.}: string
      myint {.serialize.}: int

    let obj = MyObj(mystring: "abc", myint: 1)
    let expected = """{
  "mystring": "abc",
  "myint": 1
}"""

    check obj.toJson(pretty=true) == expected