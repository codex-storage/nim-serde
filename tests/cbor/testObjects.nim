
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

  Inner = object
    s: string
    nums: seq[int]

  CompositeNested {.deserialize.} = object
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

proc fromCbor*(_: type CustomColor, n: CborNode): ?!CustomColor =
  var v: CustomColor
  if n.kind == cborNegative:
    v = CustomColor(n.int)
    success(v)
  else:
    failure(newSerdeError("Expected signed integer, got " & $n.kind))

# Custom fromCborHook for CustomPoint
proc fromCbor*(_: type CustomPoint, n: CborNode): ?!CustomPoint =
  if n.kind == cborArray and n.seq.len == 2:
    var x, y: int
    let xResult = fromCbor(x, n.seq[0])
    if xResult.isFailure:
      return failure(xResult.error)

    let yResult = fromCbor(y, n.seq[1])
    if yResult.isFailure:
      return failure(yResult.error)

    return success(CustomPoint(x: x, y: y))
  else:
    return failure(newSerdeError("Expected array of length 2 for CustomPoint"))

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

suite "CBOR deserialization":

  test "deserializes object with custom types":
    # Create a complex object
    let point = CustomPoint(x: 15, y: 25)
  # let obj = CustomObject(name: "Test Object", point: point, color: Green)

    # Create CBOR representation
    let node = createObjectCbor("Test Object", point, Green)

    # Deserialize
    # var deserializedObj: CustomObject
    # Check result
    let result = CustomObject.fromCbor(node)
    check result.isSuccess
    var deserializedObj = result.tryValue
    check deserializedObj.name == "Test Object"
    check deserializedObj.point.x == 15
    check deserializedObj.point.y == 25
    check deserializedObj.color == Green


  test "serialize and deserialize object with all supported wire types":
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

    # Serialize to CBOR with encode
    without encodedStr =? encode(original), error:
      fail()

    # Serialize to CBOR
    let stream = newStringStream()
    if stream.writeCbor(original).isFailure:
      fail()

    let cborData = stream.data
    # Check that both serialized forms are equal
    check cborData == encodedStr

    # Parse CBOR back to CborNode
    let parseResult = parseCbor(cborData)

    check parseResult.isSuccess
    let node = parseResult.tryValue

    # Deserialize to CompositeNested object
    let res = CompositeNested.fromCbor(node)
    check res.isSuccess
    let roundtrip = res.tryValue
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
