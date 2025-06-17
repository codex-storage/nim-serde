import std/json as stdjson

import pkg/questionable/results

import ../utils/errors
import ../utils/types

{.push raises: [].}

proc parse*(_: type JsonNode, json: string): ?!JsonNode =
  # Used as a replacement for `std/json.parseJson`. Will not raise Exception like in the
  # standard library
  try:
    without val =? stdjson.parseJson(json).catch, error:
      return failure error.mapErrTo(JsonParseError)
    return success val
  except Exception as e:
    return failure newException(JsonParseError, e.msg, e)
