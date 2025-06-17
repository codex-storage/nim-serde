# nim-serde

A serialization and deserialization library for Nim supporting multiple formats.

## Supported Serialization Formats

nim-serde currently supports the following serialization formats:

- **JSON**: A text-based data interchange format. [See JSON](serde/json/README.md) for details.
- **CBOR**: A binary data format following RFC 8949. [See CBOR](serde/cbor/README.md) for details.

## Quick Examples

### JSON Serialization and Deserialization

```nim
import ./serde/json
import questionable/results

# Define a type
type Person = object
  name {.serialize.}: string
  age {.serialize.}: int
  address: string # By default, serde will not serialize non-annotated fields (OptIn mode)

# Create an instance
let person = Person(name: "John Doe", age: 30, address: "123 Main St")

# Serialization
echo "JSON Serialization Example"
let jsonString = person.toJson(pretty = true)
echo jsonString

# Verify serialization output
let expectedJson = """{
  "name": "John Doe",
  "age": 30
}"""
assert jsonString == expectedJson

# Deserialization
echo "\nJSON Deserialization Example"
let jsonData = """{"name":"Jane Doe","age":28,"address":"456 Oak Ave"}"""
let result = Person.fromJson(jsonData)

# check if deserialization was successful
assert result.isSuccess

# get the deserialized value
let parsedPerson = !result

echo parsedPerson
#[
Expected Output:
Person(
  name: "Jane Doe",
  age: 28,
  address: "456 Oak Ave"
)
]#

```

### CBOR Serialization and Deserialization

```nim
import ./serde/cbor
import questionable/results
import std/streams

# Define a type
type Person = object
  name: string # Unlike JSON, CBOR always serializes all fields, and they do not need to be annotated
  age: int
  address: string

# Create an instance
let person = Person(name: "John Doe", age: 30, address: "123 Main St")

# Serialization using Stream API
echo "CBOR Stream API Serialization"
let stream = newStringStream()
let writeResult = stream.writeCbor(person)
assert writeResult.isSuccess

# Serialization using toCbor function
echo "\nCBOR toCbor Function Serialization"
let cborResult = toCbor(person)
assert cborResult.isSuccess

let serializedCbor = !cborResult

# Deserialization
echo "\nCBOR Deserialization"
let personResult = Person.fromCbor(serializedCbor)

# check if deserialization was successful
assert personResult.isSuccess

# get the deserialized value
let parsedPerson = !personResult
echo parsedPerson

#[
Expected Output:
Person(
  name: "John Doe",
  age: 30,
  address: "123 Main St"
)
]#

```

Refer to the [json](serde/json/README.md) and [cbor](serde/cbor/README.md) files for more comprehensive examples.

## Known Issues

There is a known issue when using mixins with generic overloaded procs like `fromJson`. At the time of mixin call, only the `fromJson` overloads in scope of the called mixin are available to be dispatched at runtime. There could be other `fromJson` overloads declared in other modules, but are not in scope at the time the mixin was called. 

Therefore, anytime `fromJson` is called targeting a declared overload, it may or may not be dispatchable. This can be worked around by forcing the `fromJson` overload into scope at compile time. For example, in your application where the `fromJson` overload is defined, at the bottom of the module add:

```nim
static: MyType.fromJson("")
```

This will ensure that the `MyType.fromJson` overload is dispatchable.

The basic types that serde supports should already have their overloads forced in scope in [the `deserializer` module](./serde/json/deserializer.nim#L340-L356).

For an illustration of the problem, please see this [narrow example](https://github.com/gmega/serialization-bug/tree/main/narrow) by [@gmega](https://github.com/gmega).
