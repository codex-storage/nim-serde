import ./stdjson
import ../utils/types
import std/sets


proc newUnexpectedKindError*(
    expectedType: type, expectedKinds: string, json: JsonNode
): ref UnexpectedKindError =
  let kind =
    if json.isNil:
      "nil"
    else:
      $json.kind
  newException(
    UnexpectedKindError,
    "deserialization to " & $expectedType & " failed: expected " & expectedKinds &
      " but got " & $kind,
  )

proc newUnexpectedKindError*(
    expectedType: type, expectedKinds: set[JsonNodeKind], json: JsonNode
): ref UnexpectedKindError =
  newUnexpectedKindError(expectedType, $expectedKinds, json)

proc newUnexpectedKindError*(
    expectedType: type, expectedKind: JsonNodeKind, json: JsonNode
): ref UnexpectedKindError =
  newUnexpectedKindError(expectedType, {expectedKind}, json)