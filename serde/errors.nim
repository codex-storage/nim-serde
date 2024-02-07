import std/sets

import ./stdjson
import ./types

{.push raises: [].}

proc mapErrTo*[E1: ref CatchableError, E2: SerdeError](
  e1: E1,
  _: type E2,
  msg: string = e1.msg): ref E2 =

  return newException(E2, msg, e1)

proc newSerdeError*(msg: string): ref SerdeError =
  newException(SerdeError, msg)

proc newUnexpectedKindError*(
  expectedType: type,
  expectedKinds: string,
  json: JsonNode): ref UnexpectedKindError =

  let kind = if json.isNil: "nil"
             else: $json.kind
  newException(UnexpectedKindError,
    "deserialization to " & $expectedType & " failed: expected " &
    expectedKinds & " but got " & $kind)

proc newUnexpectedKindError*(
  expectedType: type,
  expectedKinds: set[JsonNodeKind],
  json: JsonNode): ref UnexpectedKindError =

  newUnexpectedKindError(expectedType, $expectedKinds, json)

proc newUnexpectedKindError*(
  expectedType: type,
  expectedKind: JsonNodeKind,
  json: JsonNode): ref UnexpectedKindError =

  newUnexpectedKindError(expectedType, {expectedKind}, json)
