# nim-serde JSON

The JSON module in nim-serde provides serialization and deserialization for Nim values, offering an improved alternative to the standard `std/json` library. Unlike the standard library, nim-serde JSON implements a flexible system of serialization/deserialization modes that give developers precise control over how Nim objects are converted to and from JSON.

## Table of Contents
- [nim-serde JSON](#nim-serde-json)
  - [Table of Contents](#table-of-contents)
  - [Serde Modes](#serde-modes)
    - [Modes Overview](#modes-overview)
    - [Default Modes](#default-modes)
    - [Field Options](#field-options)
  - [Serialization API](#serialization-api)
    - [Basic Serialization with `%` operator](#basic-serialization-with--operator)
    - [Object Serialization](#object-serialization)
    - [Inlining JSON Directly in Code with `%*`](#inlining-json-directly-in-code-with-)
    - [Converting to JSON String with `toJson`](#converting-to-json-string-with-tojson)
    - [Serialization Modes](#serialization-modes)
    - [Field Customization for Serialization](#field-customization-for-serialization)
  - [Custom Type Serialization](#custom-type-serialization)
  - [Deserialization API](#deserialization-api)
    - [Basic Deserialization with `fromJson`](#basic-deserialization-with-fromjson)
    - [Error Handling](#error-handling)
    - [Parsing JSON with `JsonNode.parse`](#parsing-json-with-jsonnodeparse)
    - [Deserialization Modes](#deserialization-modes)
    - [Field Customization for Deserialization](#field-customization-for-deserialization)
  - [Using as a Drop-in Replacement for std/json](#using-as-a-drop-in-replacement-for-stdjson)
  - [Implementation Details](#implementation-details)


## Serde Modes
This implementation supports three different modes to control de/serialization:

```nim
OptIn
OptOut
Strict
```

Modes can be set in the `{.serialize.}` and/or `{.deserialize.}` pragmas on type
definitions. Each mode has a different meaning depending on if the type is being
serialized or deserialized. Modes can be set by setting `mode` in the `serialize` or
`deserialize` pragma annotation, eg:

```nim
type MyType {.serialize(mode=Strict).} = object
  field1: bool
  field2: bool
```

### Modes Overview

| Mode | Serialize | Deserialize |
|:-----|:----------|:------------|
| `OptOut` | All object fields will be serialized, except fields marked with `{.serialize(ignore=true).}`. | All JSON keys will be deserialized, except fields marked with `{.deserialize(ignore=true).}`. No error if extra JSON fields exist. |
| `OptIn` | Only fields marked with `{.serialize.}` will be serialized. Fields marked with `{.serialize(ignore=true).}` will not be serialized. | Only fields marked with `{.deserialize.}` will be deserialized. Fields marked with `{.deserialize(ignore=true).}` will not be deserialized. A `SerdeError` is raised if the field is missing in JSON. |
| `Strict` | All object fields will be serialized, regardless if the field is marked with `{.serialize(ignore=true).}`. | Object fields and JSON fields must match exactly, otherwise a `SerdeError` is raised. |

### Default Modes

Types can be serialized and deserialized even without explicit annotations, using default modes. Without any pragmas, types are serialized in OptIn mode and deserialized in OptOut mode. When types have pragmas but no specific mode is set, OptOut mode is used for both serialization and deserialization.


| Context | Serialize | Deserialize |
|:--------|:----------|:------------|
| Default (no pragma) | `OptIn` | `OptOut` |
| Default (pragma, but no mode) | `OptOut` | `OptOut` |

```nim
# Type is not annotated
# If you don't annotate the type, serde assumes OptIn by default for serialization, and OptOut for 
# deserialization. This means your types will be serialized to an empty string, which is probably not what you want:
type MyObj1 = object
  field1: bool
  field2: bool

# If you annotate your type but do not specify the mode, serde will default to OptOut for
# both serialize and de-serialize, meaning all fields get serialized/de-serialized by default:
# A default mode of OptOut is assumed for both serialize and deserialize.
type MyObj2 {.serialize, deserialize.} = object
  field1: bool
  field2: bool
```

### Field Options

Individual fields can be customized using the `{.serialize.}` and `{.deserialize.}` pragmas with additional options that control how each field is processed during serialization and deserialization


|          | serialize                                                                                                  | deserialize                                                                                                      |
|:---------|:-----------------------------------------------------------------------------------------------------------|:-----------------------------------------------------------------------------------------------------------------|
| `key`    | aliases the field name in json                                                                             | deserializes the field if json contains `key`                                                                    |
| `ignore` | <li>**OptOut:** field not serialized</li><li>**OptIn:** field not serialized</li><li>**Strict:** field serialized</li> | <li>**OptOut:** field not deserialized</li><li>**OptIn:** field not deserialized</li><li>**Strict:** field deserialized</li> |


Example with field options:

```nim
import pkg/serde/json

type
  Person {.serialize(mode=OptOut), deserialize(mode=OptIn).} = object
    id {.serialize(ignore=true), deserialize(key="personid").}: int
    name: string
    birthYear: int
    address: string
    phone: string

let person = Person(
              name: "Lloyd Christmas",
              birthYear: 1970,
              address: "123 Sesame Street, Providence, Rhode Island  12345",
              phone: "555-905-justgivemethedamnnumber!⛽️🔥")

let createRequest = """{
  "name": "Lloyd Christmas",
  "birthYear": 1970,
  "address": "123 Sesame Street, Providence, Rhode Island  12345",
  "phone": "555-905-justgivemethedamnnumber!⛽️🔥"
}"""
assert person.toJson(pretty=true) == createRequest

let createResponse = """{
  "personid": 1,
  "name": "Lloyd Christmas",
  "birthYear": 1970,
  "address": "123 Sesame Street, Providence, Rhode Island  12345",
  "phone": "555-905-justgivemethedamnnumber!⛽️🔥"
}"""
assert !Person.fromJson(createResponse) == Person(id: 1)
```

More examples can be found in [Serialization Modes](#serialization-modes) and [Deserialization Modes](#deserialization-modes).

## Serialization API

The nim-serde JSON serialization API provides several ways to convert Nim values to JSON.

### Basic Serialization with `%` operator

The `%` operator converts Nim values to `JsonNode` objects, which can then be converted to JSON strings:

```nim
import pkg/serde/json

# Basic types
assert %42 == newJInt(42)
assert %"hello" == newJString("hello")
assert %true == newJBool(true)

# Arrays and sequences
let arr = newJArray()
arr.add(newJInt(1))
arr.add(newJInt(2))
arr.add(newJInt(3))
assert $(%[1, 2, 3]) == $arr
```

### Object Serialization

Objects can be serialized using the `%` operator, which automatically handles field serialization based on the object's configuration:

```nim
import pkg/serde/json

type Person = object
  name {.serialize.}: string
  age {.serialize.}: int
  address: string  # Not serialized by default in OptIn mode

let person = Person(name: "John", age: 30, address: "123 Main St")
let jsonNode = %person
assert jsonNode.kind == JObject
assert jsonNode.len == 2
assert jsonNode["name"].getStr == "John"
assert jsonNode["age"].getInt == 30
assert "address" notin jsonNode
```

### Inlining JSON Directly in Code with `%*`

The `%*` macro provides a more convenient way to create JSON objects:

```nim
import pkg/serde/json

let
  name = "John"
  age = 30
  jsonObj = %*{
  "name": name,
  "age": age,
  "hobbies": ["reading", "coding"],
  "address": {
    "street": "123 Main St",
    "city": "Anytown"
  }
}

assert jsonObj.kind == JObject
assert jsonObj["name"].getStr == name
assert jsonObj["age"].getInt == age
assert jsonObj["hobbies"].kind == JArray
assert jsonObj["hobbies"][0].getStr == "reading"
assert jsonObj["address"]["street"].getStr == "123 Main St"
```

### Converting to JSON String with `toJson`

The `toJson` function converts any serializable value directly to a JSON string:

```nim
import pkg/serde/json

type Person = object
  name {.serialize.}: string
  age {.serialize.}: int

let person = Person(name: "John", age: 30)
assert person.toJson == """{"name":"John","age":30}"""
```

### Serialization Modes

nim-serde offers three modes to control which fields are serialized:

```nim
import pkg/serde/json

# OptIn mode (default): Only fields with {.serialize.} are included
type Person1 = object
  name {.serialize.}: string
  age {.serialize.}: int
  address: string  # Not serialized

assert Person1(name: "John", age: 30, address: "123 Main St").toJson == """{"name":"John","age":30}"""

# OptOut mode: All fields are included except those marked to ignore
type Person2 {.serialize.} = object
  name: string
  age: int
  ssn {.serialize(ignore=true).}: string  # Not serialized

assert Person2(name: "John", age: 30, ssn: "123-45-6789").toJson == """{"name":"John","age":30}"""

# Strict mode: All fields are included, and an error is raised if any fields are missing
type Person3 {.serialize(mode=Strict).} = object
  name: string
  age: int

assert Person3(name: "John", age: 30).toJson == """{"name":"John","age":30}"""
```

### Field Customization for Serialization

Fields can be customized with various options:

```nim
import pkg/serde/json

# Field customization for serialization
type Person {.serialize(mode = OptOut).} = object
  firstName {.serialize(key = "first_name").}: string
  lastName {.serialize(key = "last_name").}: string
  age: int  # Will be included because we're using OptOut mode
  ssn {.serialize(ignore = true).}: string  # Sensitive data not serialized

let person = Person(
  firstName: "John",
  lastName: "Doe",
  age: 30,
  ssn: "123-45-6789"
)

let jsonNode = %person
assert jsonNode.kind == JObject
assert jsonNode["first_name"].getStr == "John"
assert jsonNode["last_name"].getStr == "Doe"
assert jsonNode["age"].getInt == 30
assert "ssn" notin jsonNode

# Convert to JSON string
let jsonStr = toJson(person)
assert jsonStr == """{"first_name":"John","last_name":"Doe","age":30}"""
```

## Custom Type Serialization

You can extend nim-serde to support custom types by defining your own `%` operator overloads and `fromJson` procs:

```nim
import pkg/serde/json
import pkg/serde/utils/errors
import pkg/questionable/results
import std/strutils

# Define a custom type
type
  UserId = distinct int

# Custom serialization for UserId
proc `%`*(id: UserId): JsonNode =
  %("user-" & $int(id))

# Custom deserialization for UserId
proc fromJson*(_: type UserId, json: JsonNode): ?!UserId =
  if json.kind != JString:
    return failure(newSerdeError("Expected string for UserId, got " & $json.kind))
  
  let str = json.getStr()
  if str.startsWith("user-"):
    let idStr = str[5..^1]
    try:
      let id = parseInt(idStr)
      success(UserId(id))
    except ValueError:
      failure(newSerdeError("Invalid UserId format: " & str))
  else:
    failure(newSerdeError("UserId must start with 'user-' prefix"))

# Test serialization
let userId = UserId(42)
let jsonNode = %userId
assert jsonNode.kind == JString
assert jsonNode.getStr() == "user-42"

# Test deserialization
let jsonStr = "\"user-42\""
let parsedJson = !JsonNode.parse(jsonStr)
let result = UserId.fromJson(parsedJson)
assert result.isSuccess
assert int(!result) == 42

# Test in object context
type User {.serialize(mode = OptOut).} = object
  id: UserId
  name: string

let user = User(id: UserId(123), name: "John")
let userJson = %user
assert userJson.kind == JObject
assert userJson["id"].getStr() == "user-123"
assert userJson["name"].getStr() == "John"

# Test deserialization of object with custom type
let userJsonStr = """{"id":"user-123","name":"John"}"""
let userResult = User.fromJson(userJsonStr)
assert userResult.isSuccess
assert int((!userResult).id) == 123
assert (!userResult).name == "John"
```

## Deserialization API

nim-serde provides a type-safe way to convert JSON data back into Nim types.

### Basic Deserialization with `fromJson`

The `fromJson` function converts JSON strings or `JsonNode` objects to Nim types:

```nim
import pkg/serde/json
import pkg/questionable/results

type Person = object
  name: string
  age: int

let jsonStr = """{"name":"John","age":30}"""
let result = Person.fromJson(jsonStr)

# Using the ! operator from questionable to extract the value
assert !result == Person(name: "John", age: 30)
```

### Error Handling

Deserialization returns a `Result` type from the `questionable` library, allowing for safe error handling:

```nim
import pkg/serde/json
import pkg/questionable/results

type Person = object
  name: string
  age: int

let invalidJson = """{"name":"John","age":"thirty"}"""
let errorResult = Person.fromJson(invalidJson)
assert errorResult.isFailure
assert errorResult.error of UnexpectedKindError
```

### Parsing JSON with `JsonNode.parse`

To parse JSON string into a `JsonNode` tree instead of a deserializing to a concrete type, use `JsonNode.parse`:

```nim
import pkg/serde/json
import pkg/questionable/results

let jsonStr = """{"name":"John","age":30,"hobbies":["reading","coding"]}"""
let parseResult = JsonNode.parse(jsonStr)
assert parseResult.isSuccess
let jsonNode = !parseResult
assert jsonNode["name"].getStr == "John"
assert jsonNode["age"].getInt == 30
assert jsonNode["hobbies"].kind == JArray
assert jsonNode["hobbies"][0].getStr == "reading"
assert jsonNode["hobbies"][1].getStr == "coding"
```

### Deserialization Modes

nim-serde offers three modes to control how JSON is deserialized:

```nim
import pkg/serde/json
import pkg/questionable/results

# OptOut mode (default for deserialization)
type PersonOptOut = object
  name: string
  age: int

let jsonOptOut = """{"name":"John","age":30,"address":"123 Main St"}"""
let resultOptOut = PersonOptOut.fromJson(jsonOptOut)
assert resultOptOut.isSuccess
assert !resultOptOut == PersonOptOut(name: "John", age: 30)

# OptIn mode
type PersonOptIn {.deserialize(mode = OptIn).} = object
  name {.deserialize.}: string
  age {.deserialize.}: int
  address: string  # Not deserialized by default in OptIn mode

let jsonOptIn = """{"name":"John","age":30,"address":"123 Main St"}"""
let resultOptIn = PersonOptIn.fromJson(jsonOptIn)
assert resultOptIn.isSuccess
assert (!resultOptIn).name == "John"
assert (!resultOptIn).age == 30
assert (!resultOptIn).address == ""  # address is not deserialized

# Strict mode
type PersonStrict {.deserialize(mode = Strict).} = object
  name: string
  age: int

let jsonStrict = """{"name":"John","age":30}"""
let resultStrict = PersonStrict.fromJson(jsonStrict)
assert resultStrict.isSuccess
assert !resultStrict == PersonStrict(name: "John", age: 30)

# Strict mode with extra field (should fail)
let jsonStrictExtra = """{"name":"John","age":30,"address":"123 Main St"}"""
let resultStrictExtra = PersonStrict.fromJson(jsonStrictExtra)
assert resultStrictExtra.isFailure
```

### Field Customization for Deserialization

Fields can be customized with various options for deserialization:

```nim
import pkg/serde/json
import pkg/questionable/results

type User = object
  firstName {.deserialize(key = "first_name").}: string
  lastName {.deserialize(key = "last_name").}: string
  age: int
  internalId {.deserialize(ignore = true).}: int

let userJsonStr = """{"first_name":"Jane","last_name":"Smith","age":25,"role":"admin"}"""
let result = User.fromJson(userJsonStr)
assert result.isSuccess
assert (!result).firstName == "Jane"
assert (!result).lastName == "Smith"
assert (!result).age == 25
assert (!result).internalId == 0  # Default value, not deserialized
```

## Using as a Drop-in Replacement for std/json

nim-serde can be used as a drop-in replacement for the standard library's `json` module with improved exception handling.

```nim
# Instead of:
# import std/json
import pkg/serde/json
import pkg/questionable/results

# Using nim-serde's JSON API which is compatible with std/json
let jsonNode = %* {
  "name": "John",
  "age": 30,
  "isActive": true,
  "hobbies": ["reading", "swimming"]
}

# Accessing JSON fields using the same API as std/json
assert jsonNode.kind == JObject
assert jsonNode["name"].getStr == "John"
assert jsonNode["age"].getInt == 30
assert jsonNode["isActive"].getBool == true
assert jsonNode["hobbies"].kind == JArray
assert jsonNode["hobbies"][0].getStr == "reading"
assert jsonNode["hobbies"][1].getStr == "swimming"

# Converting JSON to string
let jsonStr = $jsonNode

# Parsing JSON from string with better error handling
let parsedResult = JsonNode.parse(jsonStr)
assert parsedResult.isSuccess
let parsedNode = !parsedResult
assert parsedNode.kind == JObject
assert parsedNode["name"].getStr == "John"

# Pretty printing
let prettyJson = pretty(jsonNode)
```

## Implementation Details

The JSON serialization in nim-serde is based on the `%` operator pattern:

1. The `%` operator converts values to `JsonNode` objects
2. Various overloads handle different types (primitives, objects, collections)
3. The `toJson` function converts the `JsonNode` to a string

This approach makes it easy to extend with custom types by defining your own `%` operator overloads.

For deserialization, the library uses compile-time reflection to map JSON fields to object fields, respecting the configuration provided by pragmas.
