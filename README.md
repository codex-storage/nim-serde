# nim-serde

Easy-to-use json serialization capabilities, and a drop-in replacement for `std/json`.

## Quick examples

Opt-in serialization by default:

```nim
import pkg/serde/json

type MyType = object
  field1 {.serialize.}: bool
  field2: bool

assert MyType(field1: true, field2: true).toJson == """{"field1":true}"""
```

Opt-out deserialization by default:

```nim
import pkg/serde/json

# All fields deserialized, as none are ignored
type MyType1 = object
  field1: bool
  field2: bool

let jsn1 = """{
                "field1": true,
                "field2": true
              }"""
assert !MyType1.fromJson(jsn1) == MyType1(field1: true, field2: true)

# Don't deserialize ignored fields in OptOut mode
type MyType2 = object
  field1 {.deserialize(ignore=true).}: bool
  field2: bool

let jsn2 = """{
                "field1": true,
                "field2": true,
                "extra": "extra fields don't error in OptOut mode"
              }"""
assert !MyType2.fromJson(jsn2) == MyType2(field1: false, field2: true)

# Note, the ! operator is part of https://github.com/codex-storage/questionable, which retrieves a value if set
```

Serialize all fields of a type (OptOut mode):

```nim
import pkg/serde/json

type MyType {.serialize.} = object
  field1: int
  field2: int

assert MyType(field1: 1, field2: 2).toJson == """{"field1":1,"field2":2}"""
```

Alias field names in both directions!

```nim
import pkg/serde/json

type MyType {.serialize.} = object
  field1 {.serialize("othername"),deserialize("takesprecedence").}: int
  field2: int

assert MyType(field1: 1, field2: 2).toJson == """{"othername":1,"field2":2}"""
let jsn = """{
                "othername":       1,
                "field2":          2,
                "takesprecedence": 3
              }"""
assert !MyType.fromJson(jsn) == MyType(field1: 3, field2: 2)
```

Supports strict mode, where type fields and json fields must match

```nim
import pkg/serde/json

type MyType {.deserialize(mode=Strict).} = object
  field1: int
  field2: int

let jsn = """{
                "field1": 1,
                "field2": 2,
                "extra":  3
              }"""

let res = MyType.fromJson(jsn)
assert res.isFailure
assert res.error of SerdeError
assert res.error.msg == "json field(s) missing in object: {\"extra\"}"
```

## Serde modes

`nim-serde` uses three different modes to control de/serialization:

```nim
OptIn
OptOut
Strict
```

Modes can be set in the `{.serialize.}` and/or `{.deserialize.}` pragmas on type definitions. Each mode has a different meaning depending on if the type is being serialized or deserialized. Modes can be set by setting `mode` in the `serialize` or `deserialize` pragma annotation, eg:

```nim
type MyType {.serialize(mode=Strict).} = object
  field1: bool
  field2: bool
```

### Modes reference

|                    | serialize                                                                                                                           | deserialize                                                                                                                                                                                                 |
|:-------------------|:------------------------------------------------------------------------------------------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `SerdeMode.OptOut` | All object fields will be serialized, except fields marked with `{.serialize(ignore=true).}`.                                       | All json keys will be deserialized, except fields marked with `{.deserialize(ignore=true).}`. No error if extra json fields exist.                                                                          |
| `SerdeMode.OptIn`  | Only fields marked with `{.serialize.}` will be serialized. Fields marked with `{.serialize(ignore=true).}` will not be serialized. | Only fields marked with `{.deserialize.}` will be deserialized. Fields marked with `{.deserialize(ignore=true).}` will not be deserialized. A `SerdeError` error is raised if the field is missing in json. |
| `SerdeMode.Strict` | All object fields will be serialized, regardless if the field is marked with `{.serialize(ignore=true).}`.                          | Object fields and json fields must match exactly, otherwise a `SerdeError` is raised.                                                                                                                       |

## Default modes

`nim-serde` will de/serialize types if they are not annotated with `serialize` or `deserialize`, but will assume a default mode. By default, with no pragmas specified, `serde` will always serialize in `OptIn` mode, meaning any fields to b Additionally, if the types are annotated, but a mode is not specified, `serde` will assume a (possibly different) default mode.

```nim
# Type is not annotated
# A default mode of OptIn (for serialize) and OptOut (for deserialize) is assumed.

type MyObj = object
  field1: bool
  field2: bool

# Type is annotated, but mode not specified
# A default mode of OptOut is assumed for both serialize and deserialize.

type MyObj {.serialize, deserialize.} = object
  field1: bool
  field2: bool
```

### Default mode reference

|                               | serialize | deserialize |
|:------------------------------|:----------|:------------|
| Default (no pragma)           | `OptIn`   | `OptOut`    |
| Default (pragma, but no mode) | `OptOut`  | `OptOut`    |

## Serde field options
Type fields can be annotated with `{.serialize.}` and `{.deserialize.}` and properties can be set on these pragmas, determining de/serialization behavior.

For example,

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

### `key`
Specifying a `key`, will alias the field name. When seriazlizing, json will be written with `key` instead of the field name. When deserializing, the json must contain `key` for the field to be deserialized.

### `ignore`
Specifying `ignore`, will prevent de/serialization on the field.

### Serde field options reference

|          | serialize                                                                                                  | deserialize                                                                                                      |
|:---------|:-----------------------------------------------------------------------------------------------------------|:-----------------------------------------------------------------------------------------------------------------|
| `key`    | aliases the field name in json                                                                             | deserializes the field if json contains `key`                                                                    |
| `ignore` | <li>**OptOut:** field not serialized</li><li>**OptIn:** field not serialized</li><li>**Strict:** field serialized</li> | <li>**OptOut:** field not deserialized</li><li>**OptIn:** field not deserialized</li><li>**Strict:** field deserialized</li> |


## Deserialization

`serde` deserializes using `fromJson`, and in all instances returns `Result[T, CatchableError]`, where `T` is the type being deserialized. For example:

```nim
type MyType = object
 field1: bool
 field2: bool

let jsn1 = """{
               "field1": true,
               "field2": true
             }"""

assert !MyType.fromJson(jsn1) == MyType(field1: true, field2: true)
```

If there was an error during deserialization, the result of `fromJson` will contain it:

```nim
import pkg/serde/json

type MyType {.deserialize(mode=Strict).} = object
  field1: int
  field2: int

let jsn = """{
                "field1": 1,
                "field2": 2,
                "extra":  3
              }"""

let res = MyType.fromJson(jsn)
assert res.isFailure
assert res.error of SerdeError
assert res.error.msg == "json field(s) missing in object: {\"extra\"}"
```

## Custom types

If `serde` can't de/serialize a custom type, de/serialization can be supported by
overloading `%` and `fromJson`. For example:

```nim
type
  Address* = distinct array[20, byte]
  SerializationError* = object of CatchableError

func `%`*(address: Address): JsonNode =
  %($address)

func fromJson(_: type Address, json: JsonNode): ?!Address =
  expectJsonKind(Address, JString, json)
  without address =? Address.init(json.getStr), error:
    return failure newException(SerializationError,
      "Failed to convert '" & $json & "' to Address: " & error.msg)
  success address
```

## Serializing to string (`toJson`)

`toJson` is a shortcut for serializing an object into its serialized string representation:

```nim
import pkg/serde/json

type MyType {.serialize.} = object
  field1: string
  field2: bool

let mt = MyType(field1: "hw", field2: true)
assert mt.toJson == """{"field1":"hw","field2":true}"""
```

This comes in handy, for example, when sending API responses:

```nim
let availability = getAvailability(...)
return RestApiResponse.response(availability.toJson,
                                contentType="application/json")
```

## `std/json` drop-in replacment

`nim-serde` can be used as a drop-in replacement for the [standard library's `json` module](https://nim-lang.org/docs/json.html), with a few notable improvements.

Instead of importing `std/json` into your application, `pkg/serde/json` can be imported instead:

```diff
- import std/json
+ import pkg/serde/json
```

As with `std/json`, `%` can be used to serialize a type into a `JsonNode`:

```nim
import pkg/serde/json

assert %"hello" == newJString("hello")
```

And `%*` can be used to serialize objects:

```nim
import pkg/serde/json

let expected = newJObject()
expected["hello"] = newJString("world")
assert %*{"hello": "world"} == expected
```

As well, serialization of types can be overridden, and serialization of custom types can be introduced. Here, we are overriding the serialization of `int`:

```nim
import pkg/serde/json

func `%`(i: int): JsonNode =
  newJInt(i + 1)

assert 1.toJson == "2"
```

## `parseJson` and exception tracking

Unfortunately, `std/json`'s `parseJson` can raise an `Exception`, so proper exception tracking breaks, eg

```nim

## Fails to compile:
## Error: parseJson(me, false, false) can raise an unlisted exception: Exception

import std/json

{.push raises:[].}

type
  MyAppError = object of CatchableError

proc parseMe(me: string): JsonNode =
  try:
    return me.parseJson
  except CatchableError as error:
    raise newException(MyAppError, error.msg)

assert """{"hello":"world"}""".parseMe == %* { "hello": "world" }
```

This is due to `std/json`'s `parseJson` incorrectly raising `Exception`. This can be worked around by instead importing `serde` and calling its `parseJson`. Note that `serde`'s `parseJson` returns a `Result[JsonNode, CatchableError]` instead of just a plain `JsonNode` object:

```nim
import pkg/serde/json

{.push raises:[].}

type
  MyAppError = object of CatchableError

proc parseMe(me: string): JsonNode {.raises: [MyAppError].} =
  without parsed =? me.parseJson, error:
    raise newException(MyAppError, error.msg)
  parsed

assert """{"hello":"world"}""".parseMe == %* { "hello": "world" }
```
