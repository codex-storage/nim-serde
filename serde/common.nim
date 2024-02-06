import std/json as stdjson except `%`, `%*`

import pkg/questionable
import pkg/questionable/results

export stdjson except `%`, `%*`, parseJson

{.push raises: [].}

type
  SerdeError* = object of CatchableError
  JsonParseError* = object of SerdeError

proc parseJson*(json: string): ?!JsonNode =
  ## fix for nim raising Exception
  try:
    return stdjson.parseJson(json).catch
  except Exception as e:
    return failure newException(JsonParseError, e.msg)
