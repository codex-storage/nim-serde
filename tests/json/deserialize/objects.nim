import std/unittest
import pkg/serde
import pkg/questionable
import pkg/questionable/results
import pkg/stew/byteutils

suite "json - deserialize objects":
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

suite "json - deserialize objects from string":
  test "deserializes objects from string":
    type MyObj = object
      mystring: string
      myint: int

    let expected = MyObj(mystring: "abc", myint: 1)
    let myObjJson =
      """{
            "mystring": "abc",
            "myint": 1
          }"""

    check !MyObj.fromJson(myObjJson) == expected

  test "deserializes ref objects from string":
    type MyRef = ref object
      mystring: string
      myint: int

    let expected = MyRef(mystring: "abc", myint: 1)
    let myRefJson =
      """{
            "mystring": "abc",
            "myint": 1
          }"""

    let deserialized = !MyRef.fromJson(myRefJson)
    check deserialized.mystring == expected.mystring
    check deserialized.myint == expected.myint

  test "deserializes seq of objects from string":
    type MyObj = object
      mystring: string
      myint: int

    let expected = @[MyObj(mystring: "abc", myint: 1)]
    let myObjsJson =
      """[{
            "mystring": "abc",
            "myint": 1
          }]"""

    check !seq[MyObj].fromJson(myObjsJson) == expected

  test "deserializes Option of object from string":
    type MyObj = object
      mystring: string
      myint: int

    let expected = some MyObj(mystring: "abc", myint: 1)
    let myObjJson =
      """{
            "mystring": "abc",
            "myint": 1
          }"""

    check !(Option[MyObj].fromJson(myObjJson)) == expected
