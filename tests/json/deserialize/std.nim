import std/math
import std/unittest
import pkg/serde
import pkg/questionable
import pkg/questionable/results

suite "json - deserialize std types":
  test "deserializes NaN float":
    check %NaN == newJString("nan")

  test "deserialize enum":
    type MyEnum = enum
      First
      Second

    let json = newJString("Second")
    check !MyEnum.fromJson(json) == Second

  test "deserializes Option[T] when has a value":
    let json = newJInt(1)
    check (!fromJson(?int, json) == some 1)

  test "deserializes Option[T] when has a string value":
    check (!fromJson(?int, "1") == some 1)

  test "deserializes Option[T] from empty string":
    check (!fromJson(?int, "") == int.none)

  test "deserializes Option[T] from empty string":
    check (!fromJson(?int, "") == int.none)

  test "cannot deserialize T from null string":
    let res = fromJson(int, "null")
    check res.error of SerdeError
    check res.error.msg == "Cannot deserialize '' or 'null' into type int"

  test "deserializes Option[T] when doesn't have a value":
    let json = newJNull()
    check !fromJson(?int, json) == none int

  test "deserializes float":
    let json = newJFloat(1.234)
    check !float.fromJson(json) == 1.234

  test "deserializes float from string":
    check !float.fromJson("1.234") == 1.234

  test "cannot deserialize float from empty string":
    let res = float.fromJson("")
    check res.error of SerdeError
    check res.error.msg == "Cannot deserialize '' or 'null' into type float"

  test "cannot deserialize float from null string":
    let res = float.fromJson("null")
    check res.error of SerdeError
    check res.error.msg == "Cannot deserialize '' or 'null' into type float"

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

  test "deserializes bool from JBool":
    let json = newJBool(true)
    check !bool.fromJson(json)

  test "deserializes bool from string":
    check !bool.fromJson("true")

  test "cannot deserialize bool from empty string":
    let res = bool.fromJson("")
    check res.error of SerdeError
    check res.error.msg == "Cannot deserialize '' or 'null' into type bool"

  test "cannot deserialize bool from null string":
    let res = bool.fromJson("null")
    check res.error of SerdeError
    check res.error.msg == "Cannot deserialize '' or 'null' into type bool"

  test "deserializes ?bool from string":
    check Option[bool].fromJson("true") == success true.some

  test "deserializes ?bool from empty string":
    check !Option[bool].fromJson("") == bool.none

  test "deserializes ?bool from null string":
    check !Option[bool].fromJson("null") == bool.none

  test "deserializes seq[bool] from JArray":
    let json = newJArray()
    json.add(newJBool(true))
    json.add(newJBool(false))
    check !seq[bool].fromJson(json) == @[true, false]

  test "deserializes seq[bool] from string":
    check !seq[bool].fromJson("[true, false]") == @[true, false]

  test "deserializes seq[bool] from empty string":
    check !seq[bool].fromJson("") == newSeq[bool]()

  test "deserializes seq[bool] from null string":
    check !seq[bool].fromJson("null") == newSeq[bool]()

  test "cannot deserialize seq[bool] from unknown string":
    let res = seq[bool].fromJson("blah")
    check res.error of JsonParseError
    check res.error.msg == "input(1, 4) Error: { expected"

  test "deserializes ?seq[bool] from string":
    check Option[seq[bool]].fromJson("[true, false]") == success @[true, false].some

  test "deserializes ?seq[bool] from empty string":
    check !Option[seq[bool]].fromJson("") == seq[bool].none

  test "deserializes ?seq[bool] from null string":
    check !Option[seq[bool]].fromJson("null") == seq[bool].none

  test "deserializes enum from JString":
    type MyEnum = enum
      one

    let json = newJString("one")
    check !MyEnum.fromJson(json) == MyEnum.one

  test "deserializes enum from string":
    type MyEnum = enum
      one

    check !MyEnum.fromJson("one") == MyEnum.one

  test "cannot deserialize enum from empty string":
    type MyEnum = enum
      one

    let res = MyEnum.fromJson("")
    check res.error of SerdeError
    check res.error.msg == "Invalid enum value: "

  test "cannot deserialize enum from null string":
    type MyEnum = enum
      one

    let res = MyEnum.fromJson("null")
    check res.error of SerdeError
    check res.error.msg == "Invalid enum value: null"

  test "deserializes ?enum from string":
    type MyEnum = enum
      one

    check Option[MyEnum].fromJson("one") == success MyEnum.one.some

  test "deserializes ?enum from empty string":
    type MyEnum = enum
      one

    check !Option[MyEnum].fromJson("") == MyEnum.none

  test "deserializes ?enum from null string":
    type MyEnum = enum
      one

    check !Option[MyEnum].fromJson("null") == MyEnum.none

  test "deserializes seq[enum] from string":
    type MyEnum = enum
      one
      two

    let res = seq[MyEnum].fromJson("[one,two]")
    check res.error of SerdeError
    check res.error.msg ==
      "Cannot deserialize a seq[enum]: not yet implemented, PRs welcome"

  test "deserializes ?seq[enum] from string":
    type MyEnum = enum
      one
      two

    let res = Option[seq[MyEnum]].fromJson("[one,two]")
    check res.error of SerdeError
    check res.error.msg ==
      "Cannot deserialize a seq[enum]: not yet implemented, PRs welcome"

  test "deserializes ?seq[MyEnum] from empty string":
    type MyEnum = enum
      one

    check !Option[seq[MyEnum]].fromJson("") == seq[MyEnum].none

  test "deserializes ?seq[MyEnum] from null string":
    type MyEnum = enum
      one

    check !Option[seq[MyEnum]].fromJson("null") == seq[MyEnum].none
