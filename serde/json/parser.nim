import std/json as stdjson

import pkg/questionable/results

import ./types

{.push raises: [].}

proc parseJson*(json: string): ?!JsonNode =
  ## fix for nim raising Exception
  try:
    return stdjson.parseJson(json).catch
  except Exception as e:
    return failure newException(JsonParseError, e.msg, e)
