import std/json
import ./errors
import std/[macros, tables, sets, sequtils]

template expectJsonKind*(
    expectedType: type, expectedKinds: set[JsonNodeKind], json: JsonNode
) =
  if json.isNil or json.kind notin expectedKinds:
    return failure(newUnexpectedKindError(expectedType, expectedKinds, json))

template expectJsonKind*(
    expectedType: type, expectedKind: JsonNodeKind, json: JsonNode
) =
  expectJsonKind(expectedType, {expectedKind}, json)

proc fieldKeys*[T](obj: T): seq[string] =
  for name, _ in fieldPairs(
    when type(T) is ref:
      obj[]
    else:
      obj
  ):
    result.add name

func keysNotIn*[T](json: JsonNode, obj: T): HashSet[string] =
  let jsonKeys = json.keys.toSeq.toHashSet
  let objKeys = obj.fieldKeys.toHashSet
  difference(jsonKeys, objKeys)

func isEmptyString*(json: JsonNode): bool =
  return json.kind == JString and json.getStr == ""

func isNullString*(json: JsonNode): bool =
  return json.kind == JString and json.getStr == "null"
