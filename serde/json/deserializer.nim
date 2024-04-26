import std/macros
import std/options
import std/sequtils
import std/sets
import std/strutils
import std/tables
import std/typetraits
import pkg/chronicles except toJson
import pkg/stew/byteutils
import pkg/stint
import pkg/questionable
import pkg/questionable/results

import ./parser
import ./errors
import ./stdjson
import ./pragmas
import ./types

export parser
export chronicles except toJson
export stdjson
export pragmas
export results
export sets
export types

{.push raises: [].}

template expectJsonKind(
    expectedType: type, expectedKinds: set[JsonNodeKind], json: JsonNode
) =
  if json.isNil or json.kind notin expectedKinds:
    return failure(newUnexpectedKindError(expectedType, expectedKinds, json))

template expectJsonKind*(expectedType: type, expectedKind: JsonNodeKind, json: JsonNode) =
  expectJsonKind(expectedType, {expectedKind}, json)

proc fieldKeys[T](obj: T): seq[string] =
  for name, _ in fieldPairs(
    when type(T) is ref:
      obj[]
    else:
      obj
  ):
    result.add name

func keysNotIn[T](json: JsonNode, obj: T): HashSet[string] =
  let jsonKeys = json.keys.toSeq.toHashSet
  let objKeys = obj.fieldKeys.toHashSet
  difference(jsonKeys, objKeys)

proc fromJson*(T: type enum, json: JsonNode): ?!T =
  expectJsonKind(string, JString, json)
  without val =? parseEnum[T](json.str).catch, error:
    return failure error.mapErrTo(SerdeError)
  return success val

proc fromJson*(_: type string, json: JsonNode): ?!string =
  if json.isNil:
    return failure newSerdeError("'json' expected, but was nil")
  elif json.kind == JNull:
    return success("null")
  elif json.isNil or json.kind != JString:
    return failure newUnexpectedKindError(string, JString, json)
  catch json.getStr

proc fromJson*(_: type bool, json: JsonNode): ?!bool =
  expectJsonKind(bool, JBool, json)
  catch json.getBool

proc fromJson*(_: type int, json: JsonNode): ?!int =
  expectJsonKind(int, JInt, json)
  catch json.getInt

proc fromJson*[T: SomeInteger](_: type T, json: JsonNode): ?!T =
  when T is uint | uint64 or (not defined(js) and int.sizeof == 4):
    expectJsonKind(T, {JInt, JString}, json)
    case json.kind
    of JString:
      without x =? parseBiggestUInt(json.str).catch, error:
        return failure newSerdeError(error.msg)
      return success cast[T](x)
    else:
      return success T(json.num)
  else:
    expectJsonKind(T, {JInt}, json)
    return success cast[T](json.num)

proc fromJson*[T: SomeFloat](_: type T, json: JsonNode): ?!T =
  expectJsonKind(T, {JInt, JFloat, JString}, json)
  if json.kind == JString:
    case json.str
    of "nan":
      let b = NaN
      return success T(b)
        # dst = NaN would fail some tests because range conversions would cause
        # CT error in some cases; but this is not a hot-spot inside this branch
        # and backend can optimize this.
    of "inf":
      let b = Inf
      return success T(b)
    of "-inf":
      let b = -Inf
      return success T(b)
    else:
      let err = newUnexpectedKindError(T, "'nan|inf|-inf'", json)
      return failure(err)
  else:
    if json.kind == JFloat:
      return success T(json.fnum)
    else:
      return success T(json.num)

proc fromJson*(_: type seq[byte], json: JsonNode): ?!seq[byte] =
  expectJsonKind(seq[byte], JString, json)
  hexToSeqByte(json.getStr).catch

proc fromJson*[N: static[int], T: array[N, byte]](_: type T, json: JsonNode): ?!T =
  expectJsonKind(T, JString, json)
  T.fromHex(json.getStr).catch

proc fromJson*[T: distinct](_: type T, json: JsonNode): ?!T =
  success T(?T.distinctBase.fromJson(json))

proc fromJson*(T: typedesc[StUint or StInt], json: JsonNode): ?!T =
  expectJsonKind(T, JString, json)
  let jsonStr = json.getStr
  let prefix = if jsonStr.len >= 2: jsonStr[0 .. 1].toLowerAscii
               else: jsonStr
  case prefix
  of "0x":
    catch parse(jsonStr, T, 16)
  of "0o":
    catch parse(jsonStr, T, 8)
  of "0b":
    catch parse(jsonStr, T, 2)
  else:
    catch parse(jsonStr, T)

proc fromJson*[T](_: type Option[T], json: JsonNode): ?!Option[T] =
  if json.isNil or json.kind == JNull:
    return success(none T)
  without val =? T.fromJson(json), error:
    return failure(error)
  success(val.some)

proc fromJson*[T](_: type seq[T], json: JsonNode): ?!seq[T] =
  expectJsonKind(seq[T], JArray, json)
  var arr: seq[T] = @[]
  for elem in json.elems:
    arr.add(?T.fromJson(elem))
  success arr

proc fromJson*[T: ref object or object](_: type T, json: JsonNode): ?!T =
  when T is JsonNode:
    return success T(json)

  expectJsonKind(T, JObject, json)
  var res =
    when type(T) is ref:
      T.new()
    else:
      T.default
  let mode = T.getSerdeMode(deserialize)

  # ensure there's no extra fields in json
  if mode == SerdeMode.Strict:
    let extraFields = json.keysNotIn(res)
    if extraFields.len > 0:
      return failure newSerdeError("json field(s) missing in object: " & $extraFields)

  for name, value in fieldPairs(
    when type(T) is ref:
      res[]
    else:
      res
  ):
    logScope:
      field = $T & "." & name
      mode

    let hasDeserializePragma = value.hasCustomPragma(deserialize)
    let opts = getSerdeFieldOptions(deserialize, name, value)
    let isOptionalValue = typeof(value) is Option
    var skip = false # workaround for 'continue' not supported in a 'fields' loop

    # logScope moved into proc due to chronicles issue: https://github.com/status-im/nim-chronicles/issues/148
    logScope:
      topics = "serde json deserialization"

    case mode
    of Strict:
      if opts.key notin json:
        return failure newSerdeError("object field missing in json: " & opts.key)
      elif opts.ignore:
        # unable to figure out a way to make this a compile time check
        warn "object field marked as 'ignore' while in Strict mode, field will be deserialized anyway"
    of OptIn:
      if not hasDeserializePragma:
        debug "object field not marked as 'deserialize', skipping"
        skip = true
      elif opts.ignore:
        debug "object field marked as 'ignore', skipping"
        skip = true
      elif opts.key notin json and not isOptionalValue:
        return failure newSerdeError("object field missing in json: " & opts.key)
    of OptOut:
      if opts.ignore:
        debug "object field is opted out of deserialization ('ignore' is set), skipping"
        skip = true
      elif hasDeserializePragma and opts.key == name:
        warn "object field marked as deserialize in OptOut mode, but 'ignore' not set, field will be deserialized"

    if not skip:
      if isOptionalValue:
        let jsonVal = json{opts.key}
        without parsed =? typeof(value).fromJson(jsonVal), e:
          debug "failed to deserialize field",
            `type` = $typeof(value), json = jsonVal, error = e.msg
          return failure(e)
        value = parsed

      # not Option[T]
      elif opts.key in json and jsonVal =? json{opts.key}.catch and not jsonVal.isNil:
        without parsed =? typeof(value).fromJson(jsonVal), e:
          debug "failed to deserialize field",
            `type` = $typeof(value), json = jsonVal, error = e.msg
          return failure(e)
        value = parsed

  success(res)

proc fromJson*(_: type JsonNode, json: string): ?!JsonNode =
  return JsonNode.parse(json)

proc fromJson*[T: ref object or object](_: type T, bytes: openArray[byte]): ?!T =
  let json = string.fromBytes(bytes)
  T.fromJson(json)

proc fromJson*[T: ref object or object](_: type T, json: string): ?!T =
  let jsn = ?JsonNode.parse(json) # full qualification required in-module only
  T.fromJson(jsn)

proc fromJson*[T: ref object or object](_: type seq[T], json: string): ?!seq[T] =
  let jsn = ?JsonNode.parse(json) # full qualification required in-module only
  seq[T].fromJson(jsn)

proc fromJson*[T: ref object or object](_: type ?T, json: string): ?!Option[T] =
  let jsn = ?JsonNode.parse(json) # full qualification required in-module only
  Option[T].fromJson(jsn)
