import std/unittest
import std/streams

import ../../serde/cbor
import ../../serde/utils/pragmas

{.push raises: [].}

suite "CBOR pragma checks":
  test "fails to compile when object marked with 'serialize' pragma":
    type SerializeTest {.serialize.} = object
      value: int

    check not compiles(toCbor(SerializeTest(value: 42)))

  test "fails to compile when object marked with 'deserialize' pragma":
    type DeserializeTest {.deserialize.} = object
      value: int

    let node = CborNode(kind: cborMap)
    check not compiles(DeserializeTest.fromCbor(node))

  test "fails to compile when field marked with 'serialize' pragma":
    type FieldSerializeTest = object
      normalField: int
      pragmaField {.serialize.}: int

    check not compiles(toCbor(FieldSerializeTest(normalField: 42, pragmaField: 100)))

  test "fails to compile when field marked with 'deserialize' pragma":
    type FieldDeserializeTest = object
      normalField: int
      pragmaField {.deserialize.}: int

    let node = CborNode(kind: cborMap)
    check not compiles(FieldDeserializeTest.fromCbor(node))

  test "compiles when type has no pragmas":
    type NoPragmaTest = object
      value: int

    check compiles(toCbor(NoPragmaTest(value: 42)))

    let node = CborNode(kind: cborMap)
    check compiles(NoPragmaTest.fromCbor(node))
