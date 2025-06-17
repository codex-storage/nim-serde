import std/unittest
import std/options
import std/streams
import std/times
import std/macros
import pkg/serde
import pkg/questionable
import pkg/questionable/results

#[
  Test types definitions
  These types are used to test various aspects of CBOR serialization/deserialization:
  - Basic types (integers, strings, etc.)
  - Custom types with custom serialization logic
  - Nested objects
  - Reference types
  - Collections (sequences, tuples)
]#
type
  # A simple 2D point with x and y coordinates
  CustomPoint = object
    x: int
    y: int

  # Enum type to test enum serialization
  CustomColor = enum
    Red
    Green
    Blue

  # Object combining different custom types
  CustomObject = object
    name: string
    point: CustomPoint
    color: CustomColor

  # Simple object with a string and sequence
  Inner = object
    s: string
    nums: seq[int]

  # Reference type for testing ref object serialization
  NewType = ref object
    size: uint64

  # Complex object with various field types to test comprehensive serialization
  CompositeNested = object
    u: uint64                                         # Unsigned integer
    n: int                                            # Signed integer
    b: seq[byte]                                      # Byte sequence
    t: string                                         # Text string
    arr: seq[int]                                     # Integer sequence
    tag: float                                        # Floating point
    flag: bool                                        # Boolean
    inner: Inner                                      # Nested object
    innerArr: seq[Inner]                              # Sequence of objects
    coordinates: tuple[x: int, y: int, label: string] # Tuple
    refInner: ref Inner                               # Reference to object
    refNewInner: NewType                              # Custom reference type
    refNil: ref Inner                                 # Nil reference
    customPoint: CustomPoint                          # Custom type
    time: Time                                        # Time
    date: DateTime                                    # DateTime

# Custom deserialization for CustomColor enum
# Converts a CBOR negative integer to a CustomColor enum value
proc fromCbor*(_: type CustomColor, n: CborNode): ?!CustomColor =
  var v: CustomColor
  if n.kind == cborNegative:
    v = CustomColor(n.int)
    success(v)
  else:
    failure(newSerdeError("Expected signed integer, got " & $n.kind))

# Custom deserialization for CustomPoint
# Expects a CBOR array with exactly 2 elements representing x and y coordinates
proc fromCbor*(_: type CustomPoint, n: CborNode): ?!CustomPoint =
  if n.kind == cborArray and n.seq.len == 2:
    let x = ?int.fromCbor(n.seq[0])
    let y = ?int.fromCbor(n.seq[1])

    return success(CustomPoint(x: x, y: y))
  else:
    return failure(newSerdeError("Expected array of length 2 for CustomPoint"))

# Custom serialization for CustomPoint
# Serializes a CustomPoint as a CBOR array with 2 elements: [x, y]
proc writeCbor*(str: Stream, val: CustomPoint): ?!void =
  # Write array header with length 2
  ?str.writeCborArrayLen(2)

  # Write x and y coordinates
  ?str.writeCbor(val.x)

  str.writeCbor(val.y)

# Helper function to create CBOR data for testing
proc createPointCbor(x, y: int): CborNode =
  result = CborNode(kind: cborArray)
  result.seq =
    @[
      CborNode(kind: cborUnsigned, uint: x.uint64),
      CborNode(kind: cborUnsigned, uint: y.uint64),
    ]

# Creates a CBOR map node representing a CustomObject
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
    # Create a test point
    let point = CustomPoint(x: 15, y: 25)

    # Create CBOR representation of a CustomObject
    let node = createObjectCbor("Test Object", point, Green)

    # Deserialize CBOR to CustomObject
    let result = CustomObject.fromCbor(node)

    # Verify deserialization was successful
    check result.isSuccess
    var deserializedObj = result.tryValue

    # Verify all fields were correctly deserialized
    check deserializedObj.name == "Test Object"
    check deserializedObj.point.x == 15
    check deserializedObj.point.y == 25
    check deserializedObj.color == Green

  test "serialize and deserialize object with all supported wire types":
    # Setup test data with various types
    # 1. Create reference objects
    var refInner = new Inner
    refInner.s = "refInner"
    refInner.nums = @[30, 40]

    var refNewObj = new NewType
    refNewObj.size = 42

    # 2. Create a complex object with all supported types
    var original = CompositeNested(
      u: 42,                                                # unsigned integer
      n: -99,                                               # signed integer
      b: @[byte 1, byte 2],                                 # byte array
      t: "hi",                                              # string
      arr: @[1, 2, 3],                                      # integer array
      tag: 1.5,                                             # float
      flag: true,                                           # boolean
      inner: Inner(s: "inner!", nums: @[10, 20]),           # nested object
      innerArr:
        @[                                                  # array of objects
          Inner(s: "first", nums: @[1, 2]), Inner(s: "second", nums: @[3, 4, 5])
        ],
      coordinates: (x: 10, y: 20, label: "test"),           # tuple
      refInner: refInner,                                   # reference to object
      refNewInner: refNewObj,                               # custom reference type
      refNil: nil,                                          # nil reference
      customPoint: CustomPoint(x: 15, y: 25),               # custom type
      time: getTime(),                                      # time
      date: now().utc,                                      # date
    )

    # Test serialization using encode helper
    without encodedStr =? toCbor(original), error:
      fail()

    # Test serialization using stream API
    let stream = newStringStream()
    check not stream.writeCbor(original).isFailure

    # Get the serialized CBOR data
    let cborData = stream.data

    # Verify both serialization methods produce the same result
    check cborData == encodedStr

    # Parse CBOR data back to CborNode
    let node = parseCbor(cborData)

    # Deserialize CborNode to CompositeNested object
    let res = CompositeNested.fromCbor(node)
    check res.isSuccess
    let roundtrip = res.tryValue

    # Verify all fields were correctly round-tripped

    # 1. Check primitive fields
    check roundtrip.u == original.u
    check roundtrip.n == original.n
    check roundtrip.b == original.b
    check roundtrip.t == original.t
    check roundtrip.arr == original.arr
    check abs(roundtrip.tag - original.tag) < 1e-6 # Float comparison with epsilon
    check roundtrip.flag == original.flag

    # 2. Check nested object fields
    check roundtrip.inner.s == original.inner.s
    check roundtrip.inner.nums == original.inner.nums

    # 3. Check sequence of objects
    check roundtrip.innerArr.len == original.innerArr.len
    for i in 0 ..< roundtrip.innerArr.len:
      check roundtrip.innerArr[i].s == original.innerArr[i].s
      check roundtrip.innerArr[i].nums == original.innerArr[i].nums

    # 4. Check tuple fields
    check roundtrip.coordinates.x == original.coordinates.x
    check roundtrip.coordinates.y == original.coordinates.y
    check roundtrip.coordinates.label == original.coordinates.label

    # 5. Check reference fields
    check not roundtrip.refInner.isNil
    check roundtrip.refInner.s == original.refInner.s
    check roundtrip.refInner.nums == original.refInner.nums

    # 6. Check nil reference
    check roundtrip.refNil.isNil

    # 7. Check custom type
    check roundtrip.customPoint.x == original.customPoint.x
    check roundtrip.customPoint.y == original.customPoint.y
