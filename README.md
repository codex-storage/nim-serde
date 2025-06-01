# nim-serde

A serialization and deserialization library for Nim supporting multiple wire formats.

## Supported Wire Formats

nim-serde currently supports the following wire formats:

- **JSON**: A text-based data interchange format. [See JSON](serde/json/README.md) for details.
- **CBOR**: A binary data format following RFC 8949. [See CBOR](serde/cbor/README.md) for details.

## Serde modes

`nim-serde` uses three different modes to control de/serialization:

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

### Modes reference

|                    | serialize                                                                                                                           | deserialize                                                                                                                                                                                                 |
|:-------------------|:------------------------------------------------------------------------------------------------------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `SerdeMode.OptOut` | All object fields will be serialized, except fields marked with `{.serialize(ignore=true).}`.                                       | All json keys will be deserialized, except fields marked with `{.deserialize(ignore=true).}`. No error if extra json fields exist.                                                                          |
| `SerdeMode.OptIn`  | Only fields marked with `{.serialize.}` will be serialized. Fields marked with `{.serialize(ignore=true).}` will not be serialized. | Only fields marked with `{.deserialize.}` will be deserialized. Fields marked with `{.deserialize(ignore=true).}` will not be deserialized. A `SerdeError` error is raised if the field is missing in json. |
| `SerdeMode.Strict` | All object fields will be serialized, regardless if the field is marked with `{.serialize(ignore=true).}`.                          | Object fields and json fields must match exactly, otherwise a `SerdeError` is raised.                                                                                                                       |

## Default modes

`nim-serde` will de/serialize types if they are not annotated with `serialize` or
`deserialize`, but will assume a default mode. By default, with no pragmas specified,
`serde` will always serialize in `OptIn` mode, meaning any fields to b Additionally, if
the types are annotated, but a mode is not specified, `serde` will assume a (possibly
different) default mode.

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
Type fields can be annotated with `{.serialize.}` and `{.deserialize.}` and properties
can be set on these pragmas, determining de/serialization behavior.

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
Specifying a `key`, will alias the field name. When seriazlizing, json will be written
with `key` instead of the field name. When deserializing, the json must contain `key`
for the field to be deserialized.

### `ignore`
Specifying `ignore`, will prevent de/serialization on the field.

### Serde field options reference

|          | serialize                                                                                                  | deserialize                                                                                                      |
|:---------|:-----------------------------------------------------------------------------------------------------------|:-----------------------------------------------------------------------------------------------------------------|
| `key`    | aliases the field name in json                                                                             | deserializes the field if json contains `key`                                                                    |
| `ignore` | <li>**OptOut:** field not serialized</li><li>**OptIn:** field not serialized</li><li>**Strict:** field serialized</li> | <li>**OptOut:** field not deserialized</li><li>**OptIn:** field not deserialized</li><li>**Strict:** field deserialized</li> |




## Known Issues

There is a known issue when using mixins with generic overloaded procs like `fromJson`. At the time of mixin call, only the `fromJson` overloads in scope of the called mixin are available to be dispatched at runtime. There could be other `fromJson` overloads declared in other modules, but are not in scope at the time the mixin was called. 

Therefore, anytime `fromJson` is called targeting a declared overload, it may or may not be dispatchable. This can be worked around by forcing the `fromJson` overload into scope at compile time. For example, in your application where the `fromJson` overload is defined, at the bottom of the module add:

```nim
static: MyType.fromJson("")
```

This will ensure that the `MyType.fromJson` overload is dispatchable.

The basic types that serde supports should already have their overloads forced in scope in [the `deserializer` module](./serde/json/deserializer.nim#L340-L356).

For an illustration of the problem, please see this [narrow example](https://github.com/gmega/serialization-bug/tree/main/narrow) by [@gmega](https://github.com/gmega).
