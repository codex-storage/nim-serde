import pkg/serde
import std/[times]
import pkg/questionable
import pkg/questionable/results
import pkg/stew/byteutils
import pkg/stint

import serde/json/serializer
import serde/cbor/serializer
import serde/cbor/deserializer

type Inner {.serialize.} = object
  size: uint64

type CustomPoint {.serialize.} = object
  u: uint64            # Unsigned integer
  n: int               # Signed integer
  b: seq[byte]         # Byte sequence
  t: string            # Text string
  arr: seq[int]        # Integer sequence
  tag: float           # Floating point
  flag: bool           # Boolean
  inner: Inner         # Nested object
  innerArr: seq[Inner] # Sequence of objects

proc generateCustomPoint(): CustomPoint =
  CustomPoint(
    u: 1234567890,
    n: -1234567890,
    b: "hello world".toBytes,
    t: "hello world",
    arr: @[1, 2, 3, 4, 5],
    tag: 3.14,
    flag: true,
    inner: Inner(size: 1234567890),
    innerArr: @[Inner(size: 1234567890), Inner(size: 9543210)],
  )

proc benchmark(): void =
  let point = generateCustomPoint()
  var jsonStr = ""
  var cborStr = ""
  let jsonStartTime = cpuTime()

  for i in 1 .. 100000:
    jsonStr = toJson(point)
  let jsonEndTime = cpuTime()
  let jsonDuration = jsonEndTime - jsonStartTime

  let cborStartTime = cpuTime()
  for i in 1 .. 100000:
    cborStr = toCbor(point).tryValue
  let cborEndTime = cpuTime()
  let cborDuration = cborEndTime - cborStartTime

  let jsonDeserializeStartTime = cpuTime()
  for i in 1 .. 100000:
    assert CustomPoint.fromJson(jsonStr).isSuccess
  let jsonDeserializeEndTime = cpuTime()
  let jsonDeserializeDuration = jsonDeserializeEndTime - jsonDeserializeStartTime

  let cborDeserializeStartTime = cpuTime()
  for i in 1 .. 100000:
    assert CustomPoint.fromCbor(cborStr).isSuccess
  let cborDeserializeEndTime = cpuTime()
  let cborDeserializeDuration = cborDeserializeEndTime - cborDeserializeStartTime

  echo "JSON Serialization Time: ", jsonDuration
  echo "CBOR Serialization Time: ", cborDuration
  echo "JSON Deserialization Time: ", jsonDeserializeDuration
  echo "CBOR Deserialization Time: ", cborDeserializeDuration

when isMainModule:
  benchmark()
