# nim-serde CBOR

This README details the usage of CBOR serialization and deserialization features offered by nim-serde, in compliance with [RFC 8949](https://datatracker.ietf.org/doc/html/rfc8949).

## Table of Contents
- [nim-serde CBOR](#nim-serde-cbor)
  - [Table of Contents](#table-of-contents)
  - [Serialization API](#serialization-api)
    - [Basic Serialization with Stream API](#basic-serialization-with-stream-api)
    - [Object Serialization](#object-serialization)
    - [Custom Type Serialization](#custom-type-serialization)
    - [Converting to CBOR with `toCbor`](#converting-to-cbor-with-tocbor)
    - [Working with CborNode](#working-with-cbornode)
    - [Convenience Functions for CborNode](#convenience-functions-for-cbornode)
  - [Deserialization API](#deserialization-api)
    - [Basic Deserialization with `fromCbor`](#basic-deserialization-with-fromcbor)
    - [Error Handling](#error-handling)
    - [Parsing CBOR with `parseCbor`](#parsing-cbor-with-parsecbor)
    - [Custom Type Deserialization](#custom-type-deserialization)
  - [Implementation Details](#implementation-details)
    - [Current Limitations](#current-limitations)

## Serialization API

The nim-serde CBOR serialization API provides several ways to convert Nim values to CBOR.

### Basic Serialization with Stream API

The `writeCbor` function writes Nim values to a stream in CBOR format:

```nim
import pkg/serde/cbor
import pkg/questionable/results
import std/streams

# Create a stream to write to
let stream = newStringStream()

# Basic types
discard stream.writeCbor(42)           # Unsigned integer
discard stream.writeCbor(-10)          # Negative integer
discard stream.writeCbor(3.14)         # Float
discard stream.writeCbor("hello")      # String
discard stream.writeCbor(true)         # Boolean

# Arrays and sequences
discard stream.writeCbor(@[1, 2, 3])   # Sequence

# Get the serialized CBOR data
let cborData = stream.data
```

### Object Serialization

Objects can be serialized to CBOR format using the stream API:

```nim
import pkg/serde/cbor
import pkg/questionable/results
import std/streams

type Person = object
  name: string
  age: int
  isActive: bool

let person = Person(
  name: "John",
  age: 30,
  isActive: true
)

# Serialize the object to CBOR
let stream = newStringStream()
discard stream.writeCbor(person)

# Get the serialized CBOR data
let cborData = stream.data
```

### Custom Type Serialization

You can extend nim-serde to support custom types by defining your own `writeCbor` procs:

```nim
import pkg/serde/cbor
import pkg/questionable/results
import std/streams
import std/strutils

# Define a custom type
type
  UserId = distinct int

# Custom serialization for UserId
proc writeCbor*(str: Stream, id: UserId): ?!void =
  # Write as a CBOR text string with a prefix
  str.writeCbor("user-" & $int(id))

# Test serialization
let userId = UserId(42)
let stream = newStringStream()
discard stream.writeCbor(userId)
let cborData = stream.data

# Test in object context
type User = object
  id: UserId
  name: string

let user = User(id: UserId(123), name: "John")
let userStream = newStringStream()
discard userStream.writeCbor(user)
let userCborData = userStream.data
```

### Converting to CBOR with `toCbor`

The `toCbor` function can be used to directly convert a Nim value to CBOR binary data:

```nim
import pkg/serde/cbor
import pkg/questionable/results

type Person = object
  name: string
  age: int
  isActive: bool

let person = Person(
  name: "John",
  age: 30,
  isActive: true
)

# Convert to CBOR binary data
let result = toCbor(person)
assert result.isSuccess
let cborData = !result
```

### Working with CborNode

The `CborNode` type represents CBOR data in memory and can be manipulated directly:

```nim
import pkg/serde/cbor
import pkg/questionable/results
import std/tables

# Create CBOR nodes
let textNode = CborNode(kind: cborText, text: "hello")
let intNode = CborNode(kind: cborUnsigned, uint: 42'u64)
let floatNode = CborNode(kind: cborFloat, float: 3.14)

# Create an array
var arrayNode = CborNode(kind: cborArray)
arrayNode.seq = @[textNode, intNode, floatNode]

# Create a map with text keys and boolean values
var mapNode = CborNode(kind: cborMap)
mapNode.map = initOrderedTable[CborNode, CborNode]()
# Boolean values are represented as simple values (21 for true, 20 for false)
mapNode.map[CborNode(kind: cborText, text: "a")] = CborNode(kind: cborSimple, simple: 21) # true
mapNode.map[CborNode(kind: cborText, text: "b")] = CborNode(kind: cborSimple, simple: 20) # false

# Convert to CBOR binary data
let result = toCbor(mapNode)
assert result.isSuccess
let cborData = !result
```

### Convenience Functions for CborNode

The library provides convenience functions for creating CBOR nodes:

```nim
import pkg/serde/cbor
import pkg/questionable/results

# Initialize CBOR nodes
let bytesNode = initCborBytes(@[byte 1, byte 2, byte 3])
let textNode = initCborText("hello")
let arrayNode = initCborArray()
let mapNode = initCborMap()

# Convert values to CborNode
let intNodeResult = toCborNode(42)
assert intNodeResult.isSuccess
let intNode = !intNodeResult

let strNodeResult = toCborNode("hello")
assert strNodeResult.isSuccess
let strNode = !strNodeResult

let boolNodeResult = toCborNode(true)
assert boolNodeResult.isSuccess
let boolNode = !boolNodeResult
```

## Deserialization API

The nim-serde CBOR deserialization API provides ways to convert CBOR data back to Nim values.

### Basic Deserialization with `fromCbor`

The `fromCbor` function converts CBOR data to Nim values:

```nim
import pkg/serde/cbor
import pkg/questionable/results
import std/streams

# Create some CBOR data
let stream = newStringStream()
discard stream.writeCbor(42)
let cborData = stream.data

# Parse the CBOR data into a CborNode
try:
  let node = parseCbor(cborData)
  
  # Deserialize the CborNode to a Nim value
  let intResult = int.fromCbor(node)
  assert intResult.isSuccess
  let value = !intResult
  assert value == 42
  
  # You can also deserialize to other types
  # For example, if cborData contained a string:
  # let strResult = string.fromCbor(node)
  # assert strResult.isSuccess
  # let strValue = !strResult

# Deserialize to an object
type Person = object
  name: string
  age: int
  isActive: bool

let personResult = Person.fromCbor(node)
assert personResult.isSuccess
let person = !personResult

# Verify the deserialized data
assert person.name == "John"
assert person.age == 30
assert person.isActive == true
```

### Error Handling

Deserialization returns a `Result` type from the `questionable` library, allowing for safe error handling:

```nim
import pkg/serde/cbor
import pkg/questionable/results

# Invalid CBOR data for an integer
let invalidNode = CborNode(kind: cborText, text: "not an int")
let result = int.fromCbor(invalidNode)

# Check for failure
assert result.isFailure
echo result.error.msg
# Output: "deserialization to int failed: expected {cborUnsigned, cborNegative} but got cborText"
```

### Parsing CBOR with `parseCbor`

The `parseCbor` function parses CBOR binary data into a `CborNode`:

```nim
import pkg/serde/cbor
import pkg/questionable/results

# Parse CBOR data
let node = parseCbor(cborData)

# Check node type and access data
case node.kind
of cborUnsigned:
  echo "Unsigned integer: ", node.uint
of cborNegative:
  echo "Negative integer: ", node.int
of cborText:
  echo "Text: ", node.text
of cborArray:
  echo "Array with ", node.seq.len, " items"
of cborMap:
  echo "Map with ", node.map.len, " pairs"
else:
  echo "Other CBOR type: ", node.kind
```

### Custom Type Deserialization

You can extend nim-serde to support custom type deserialization by defining your own `fromCbor` procs:

```nim
import pkg/serde/cbor
import pkg/questionable/results
import std/strutils

# Define a custom type
type
  UserId = distinct int

# Custom deserialization for UserId
proc fromCbor*(_: type UserId, n: CborNode): ?!UserId =
  if n.kind != cborText:
    return failure(newSerdeError("Expected string for UserId, got " & $n.kind))
  
  let str = n.text
  if str.startsWith("user-"):
    let idStr = str[5..^1]
    try:
      let id = parseInt(idStr)
      success(UserId(id))
    except ValueError:
      failure(newSerdeError("Invalid UserId format: " & str))
  else:
    failure(newSerdeError("UserId must start with 'user-' prefix"))

# Test deserialization
let node = parseCbor(cborData)  # Assuming cborData contains a serialized UserId
let result = UserId.fromCbor(node)
assert result.isSuccess
assert int(!result) == 42

# Test deserialization in object context
type User = object
  id: UserId
  name: string

let userNode = parseCbor(userCborData)  # Assuming userCborData contains a serialized User
let userResult = User.fromCbor(userNode)
assert userResult.isSuccess
assert int((!userResult).id) == 123
assert (!userResult).name == "John"
```


## Implementation Details

The CBOR serialization in nim-serde follows a stream-based approach:

```
# Serialization flow
Nim value → writeCbor → CBOR binary data

# Deserialization flow
CBOR binary data → parseCbor (CborNode) → fromCbor → Nim value
```

Unlike the JSON implementation which uses the `%` operator pattern, the CBOR implementation uses a hook-based approach:

1. The `writeCbor` function writes Nim values directly to a stream in CBOR format
2. Custom types can be supported by defining `writeCbor` procs for those types
3. The `toCbor` function provides a convenient way to convert values to CBOR binary data

For deserialization, the library parses CBOR data into a `CborNode` representation, which can then be converted to Nim values using the `fromCbor` function. This approach allows for flexible handling of CBOR data while maintaining type safety.

### Current Limitations

While the JSON implementation supports serde modes via pragmas, the current CBOR implementation does not support the `serialize` and `deserialize` pragmas. The library will raise an assertion error if you try to use these pragmas with CBOR serialization.

```nim
import pkg/serde/cbor

type Person {.serialize(mode = OptOut).} = object  # This will raise an assertion error
  name: string
  age: int
  isActive: bool
```

