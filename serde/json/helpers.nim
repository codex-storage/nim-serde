import std/json

func isEmptyString*(json: JsonNode): bool =
  return json.kind == JString and json.getStr == ""

func isNullString*(json: JsonNode): bool =
  return json.kind == JString and json.getStr == "null"
