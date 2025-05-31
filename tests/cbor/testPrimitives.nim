# This file is a modified version of Emery Hemingway’s CBOR library for Nim,
# originally available at https://github.com/ehmry/cbor-nim and released under The Unlicense.

import std/[base64, os, random, times, json, unittest]
import pkg/serde/cbor
import pkg/questionable
import pkg/questionable/results

proc findVectorsFile(): string =
  var parent = getCurrentDir()
  while parent != "/":
    result = parent / "tests" / "cbor" / "test_vector.json"
    if fileExists result:
      return
    parent = parent.parentDir
  raiseAssert "Could not find test vectors"

let js = findVectorsFile().readFile.parseJson()

suite "decode":
  for v in js.items:
    if v.hasKey "decoded":
      let
        control = $v["decoded"]
        name = v["name"].getStr
      test name:
        let controlCbor = base64.decode v["cbor"].getStr
        let js = parseCbor(controlCbor).toJson()
        if js.isNil:
          fail()
        else:
          check(control == $js)

suite "diagnostic":
  for v in js.items:
    if v.hasKey "diagnostic":
      let
        control = v["diagnostic"].getStr
        name = v["name"].getStr
      test name:
        let controlCbor = base64.decode v["cbor"].getStr
        check($parseCbor(controlCbor) == control)

suite "roundtrip":
  for v in js.items:
    if v["roundtrip"].getBool:
      let
        controlB64 = v["cbor"].getStr
        controlCbor = base64.decode controlB64
        name = v["name"].getStr
      test name:
        without testCbor =? toCbor(parseCbor(controlCbor)), error:
          fail()
        if controlCbor != testCbor:
          let testB64 = base64.encode(testCbor)
          check(controlB64 == testB64)

suite "hooks":
  test "DateTime":
    let dt = now()

    without bin =? toCbor(dt), error:
      fail()
    check(parseCbor(bin).text == $dt)
  test "Time":
    let t = now().toTime
    var bin = toCbor(t).tryValue
    check(parseCbor(bin).getInt == t.toUnix)

test "tag":
  var c = toCborNode("foo").tryValue
  c.tag = some(99'u64)
  check c.tag == some(99'u64)

test "sorting":
  var map = initCborMap()
  var keys =
    @[
      toCborNode(10).tryValue,
      toCborNode(100).tryValue,
      toCborNode(-1).tryValue,
      toCborNode("z").tryValue,
      toCborNode("aa").tryValue,
      toCborNode([toCborNode(100).tryValue]).tryValue,
      toCborNode([toCborNode(-1).tryValue]).tryValue,
      toCborNode(false).tryValue,
    ]
  shuffle(keys)

  for k in keys:
    map[k] = toCborNode(0).tryValue
  check not map.isSorted.tryValue
  check sort(map).isSuccess
  check map.isSorted.tryValue

test "invalid wire type":
  let node = CborNode(kind: cborText, text: "not an int")
  let result = int.fromCbor(node)

  check result.isFailure
  check $result.error.msg ==
    "deserialization to int failed: expected {cborUnsigned, cborNegative} but got cborText"
