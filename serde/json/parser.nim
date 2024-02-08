import std/json as stdjson

import pkg/questionable/results

import ./types

{.push raises: [].}

proc parse*(_: type JsonNode, json: string): ?!JsonNode =
  # Used as a replacement for `std/json.parseJson`. Will not raise Exception like in the
  # standard library
  try:
    return stdjson.parseJson(json).catch
  except Exception as e:
    return failure newException(JsonParseError, e.msg, e)
