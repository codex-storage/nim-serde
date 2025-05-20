# File: /Users/rahul/Work/repos/nim-serde/tests/cbor_questionable.nim

import std/unittest
import std/options
import std/streams
import pkg/serde
import pkg/questionable
import pkg/questionable/results

# Custom type for testing
type
  CustomPoint = object
    x: int
    y: int

  CustomColor = enum
    Red, Green, Blue

  CustomObject = object
    name: string
    point: CustomPoint
    color: CustomColor

  Person = object
    name: string
    age: int
    isActive: bool

  Inner = object
    s: string
    nums: seq[int]

  CompositeNested = object
    u: uint64
    n: int
    b: seq[byte]
    t: string
    arr: seq[int]
    tag: float
    flag: bool
    inner: Inner
    innerArr: seq[Inner]
    coordinates: tuple[x: int, y: int, label: string]
    refInner: ref Inner

proc fromCborHook*(v: var CustomColor, n: CborNode): ?!void =
  if n.kind == cborNegative:
    v = CustomColor(n.int)
    result = success()
  else:
    result = failure(newSerdeError("Expected signed integer, got " & $n.kind))

# Custom fromCborHook for CustomPoint
proc fromCborHook*(v: var CustomPoint, n: CborNode): ?!void =
  if n.kind == cborArray and n.seq.len == 2:
    var x, y: int
    let xResult = fromCborQ2(x, n.seq[0])
    if xResult.isFailure:
      return failure(xResult.error)

    let yResult = fromCborQ2(y, n.seq[1])
    if yResult.isFailure:
      return failure(yResult.error)

    v = CustomPoint(x: x, y: y)
    result = success()
  else:
    result = failure(newSerdeError("Expected array of length 2 for CustomPoint"))

# Helper function to create CBOR data for testing
proc createPointCbor(x, y: int): CborNode =
  result = CborNode(kind: cborArray)
  result.seq = @[
    CborNode(kind: cborUnsigned, uint: x.uint64),
    CborNode(kind: cborUnsigned, uint: y.uint64)
  ]

proc createObjectCbor(name: string, point: CustomPoint,
    color: CustomColor): CborNode =
  result = CborNode(kind: cborMap)
  result.map = initOrderedTable[CborNode, CborNode]()

  # Add name field
  result.map[CborNode(kind: cborText, text: "name")] =
    CborNode(kind: cborText, text: name)

  # Add point field
  result.map[CborNode(kind: cborText, text: "point")] =
    createPointCbor(point.x, point.y)

  # Add color field
  result.map[CborNode(kind: cborText, text: "color")] =
    CborNode(kind: cborNegative, int: color.int)

suite "CBOR deserialization with Questionable":
  test "fromCborQ2 with primitive types":
    # Test with integer
    block:
      var intValue: int
      let node = CborNode(kind: cborUnsigned, uint: 42.uint64)
      let result = fromCborQ2(intValue, node)

      check result.isSuccess
      check intValue == 42

    # Test with string
    block:
      var strValue: string
      let node = CborNode(kind: cborText, text: "hello")
      let result = fromCborQ2(strValue, node)

      check result.isSuccess
      check strValue == "hello"

    # Test with error case
    block:
      var intValue: int
      let node = CborNode(kind: cborText, text: "not an int")
      let result = fromCborQ2(intValue, node)

      check result.isFailure
      check $result.error.msg == "deserialization to int failed: expected {cborUnsigned, cborNegative} but got cborText"

      test "parseCborAs with valid input":
      # Create a valid CBOR object for a Person
        var mapNode = CborNode(kind: cborMap)
        mapNode.map = initOrderedTable[CborNode, CborNode]()
        mapNode.map[CborNode(kind: cborText, text: "a")] = CborNode(
            kind: cborText, text: "John Doe")
        mapNode.map[CborNode(kind: cborText, text: "b")] = CborNode(
            kind: cborUnsigned, uint: 30)
        mapNode.map[CborNode(kind: cborText, text: "c")] = CborNode(
            kind: cborSimple, simple: 21) # true
        var p1: Person
        p1.name = "John Doe"
        p1.age = 30
        p1.isActive = true

        let stream = newStringStream()
        stream.writeCbor(p1)
        let cborData = stream.data

        # var cborNode = parseCbor(cborData)
        # check cborNode.isSuccess
        # echo cborNode.tryError.msg

        without parsedNode =? parseCbor(cborData), error:
          echo error.msg

        # Parse directly to Person object
        var person: Person
        let result = fromCborQ2(person, parsedNode)

        check result.isSuccess
        check person.name == "John Doe"
        check person.age == 30
        check person.isActive == true

  test "fromCborQ2 with custom hook":
    # Test with valid point data
    block:
      var point: CustomPoint
      let node = createPointCbor(10, 20)
      let result = fromCborQ2(point, node)

      check result.isSuccess
      check point.x == 10
      check point.y == 20

    # Test with invalid point data
    block:
      var point: CustomPoint
      let elements = @[toCbor(10)]
      let node = toCbor(elements)
      let result = fromCborQ2(point, node)

      check result.isFailure
    # check "Expected array of length 2" in $result.error.msg

  test "fromCborQ2 with complex object":
    # Create a complex object
    let point = CustomPoint(x: 15, y: 25)
  # let obj = CustomObject(name: "Test Object", point: point, color: Green)

    # Create CBOR representation
    let node = createObjectCbor("Test Object", point, Green)

    # Deserialize
    var deserializedObj: CustomObject
    # Check result
    let result = fromCborQ2(deserializedObj, node)
    check result.isSuccess
    check deserializedObj.name == "Test Object"
    check deserializedObj.point.x == 15
    check deserializedObj.point.y == 25
    check deserializedObj.color == Green

  suite "CBOR round-trip for nested composite object":
    test "serialize and parse nested composite type":
      var refObj = new Inner
      refObj.s = "refInner"
      refObj.nums = @[30, 40]
      var original = CompositeNested(
        u: 42,
        n: -99,
        b: @[byte 1, byte 2],
        t: "hi",
        arr: @[1, 2, 3],
        tag: 1.5,
        flag: true,
        inner: Inner(s: "inner!", nums: @[10, 20]),
        innerArr: @[
          Inner(s: "first", nums: @[1, 2]),
          Inner(s: "second", nums: @[3, 4, 5])
        ],
        coordinates: (x: 10, y: 20, label: "test"),
        refInner: refObj
      )

      # Serialize to CBOR
      let stream = newStringStream()
      stream.writeCbor(original)
      let cborData = stream.data
      # Parse CBOR back to CborNode
      let parseResult = parseCbor(cborData)
      check parseResult.isSuccess
      let node = parseResult.tryValue

      # Deserialize to CompositeNested object
      var roundtrip: CompositeNested
      let deserResult = fromCborQ2(roundtrip, node)
      check deserResult.isSuccess

      # Check top-level fields
      check roundtrip.u == original.u
      check roundtrip.n == original.n
      check roundtrip.b == original.b
      check roundtrip.t == original.t
      check roundtrip.arr == original.arr
      check abs(roundtrip.tag - original.tag) < 1e-6
      check roundtrip.flag == original.flag

      # Check nested object
      check roundtrip.inner.s == original.inner.s
      check roundtrip.inner.nums == original.inner.nums

      # Check nested array of objects
      check roundtrip.innerArr.len == original.innerArr.len
      for i in 0..<roundtrip.innerArr.len:
        check roundtrip.innerArr[i].s == original.innerArr[i].s
        check roundtrip.innerArr[i].nums == original.innerArr[i].nums

      check roundtrip.coordinates.x == original.coordinates.x
      check roundtrip.coordinates.y == original.coordinates.y
      check roundtrip.coordinates.label == original.coordinates.label


      check not roundtrip.refInner.isNil
      check roundtrip.refInner.s == original.refInner.s
      check roundtrip.refInner.nums == original.refInner.nums
