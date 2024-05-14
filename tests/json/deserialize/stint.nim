import std/options
import std/unittest
import pkg/stint
import pkg/serde
import pkg/questionable
import pkg/questionable/results

suite "json - deserialize stint":
  test "deserializes UInt256 from an empty JString":
    let json = newJString("")
    check !UInt256.fromJson(json) == 0.u256

  test "deserializes UInt256 from an empty string":
    check !UInt256.fromJson("") == 0.u256

  test "deserializes ?UInt256 from an empty JString":
    let json = newJString("")
    check !Option[UInt256].fromJson(json) == 0.u256.some

  test "deserializes ?UInt256 from an empty string":
    check !Option[UInt256].fromJson("") == 0.u256.some

  test "deserializes UInt256 from JString with no prefix":
    let json = newJString("1")
    check !UInt256.fromJson(json) == 1.u256

  test "deserializes ?UInt256 from JString with no prefix":
    let json = newJString("1")
    check !Option[UInt256].fromJson(json) == 1.u256.some

  test "deserializes UInt256 from string with no prefix":
    check !UInt256.fromJson("1") == 1.u256

  test "deserializes ?UInt256 from string with no prefix":
    check !Option[UInt256].fromJson("1") == 1.u256.some

  test "deserializes UInt256 from hex JString representation":
    let json = newJString("0x1")
    check !UInt256.fromJson(json) == 0x1.u256

  test "deserializes ?UInt256 from hex JString representation":
    let json = newJString("0x1")
    check !Option[UInt256].fromJson(json) == 0x1.u256.some

  test "deserializes ?UInt256 from hex string representation":
    check !Option[UInt256].fromJson("0x1") == 0x1.u256.some

  test "deserializes UInt256 from octal JString representation":
    let json = newJString("0o1")
    check !UInt256.fromJson(json) == 0o1.u256

  test "deserializes ?UInt256 from octal JString representation":
    let json = newJString("0o1")
    check !Option[UInt256].fromJson(json) == 0o1.u256.some

  test "deserializes ?UInt256 from octal string representation":
    check !Option[UInt256].fromJson("0o1") == 0o1.u256.some

  test "deserializes UInt256 from binary JString representation":
    let json = newJString("0b1")
    check !UInt256.fromJson(json) == 0b1.u256

  test "deserializes ?UInt256 from binary JString representation":
    let json = newJString("0b1")
    check !Option[UInt256].fromJson(json) == 0b1.u256.some

  test "deserializes ?UInt256 from binary string representation":
    check !Option[UInt256].fromJson("0b1") == 0b1.u256.some

  test "deserializes Int256 with no prefix":
    let json = newJString("1")
    check !Int256.fromJson(json) == 1.i256
