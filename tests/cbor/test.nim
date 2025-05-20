import
  std/[base64, os, random, times, json, unittest]
import pkg/serde/cbor
import pkg/questionable
import pkg/questionable/results

proc findVectorsFile: string =
  var parent = getCurrentDir()
  while parent != "/":
    result = parent / "tests" / "cbor" / "test_vector.json"
    if fileExists result: return
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
        let
          controlCbor = base64.decode v["cbor"].getStr
        without c =? parseCbor(controlCbor), error:
          fail()
        let js = c.toJsonHook()
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
        let
          controlCbor = base64.decode v["cbor"].getStr
        without c =? parseCbor(controlCbor), error:
          fail()
        check($c == control)

suite "roundtrip":
  for v in js.items:
    if v["roundtrip"].getBool:
      let
        controlB64 = v["cbor"].getStr
        controlCbor = base64.decode controlB64
        name = v["name"].getStr
      without c =? parseCbor(controlCbor), error:
        fail()
      test name:
        let testCbor = encode(c)
        if controlCbor != testCbor:
          let testB64 = base64.encode(testCbor)
          check(controlB64 == testB64)

suite "hooks":
  test "DateTime":
    let dt = now()
    var
      bin = encode(dt)
    without node =? parseCbor(bin), error:
      fail()
    check(node.text == $dt)
  test "Time":
    let t = now().toTime
    var
      bin = encode(t)
    without node =? parseCbor(bin), error:
      fail()

    check(node.getInt == t.toUnix)

test "tag":
  var c = toCbor("foo")
  c.tag = some(99'u64)
  check c.tag == some(99'u64)

test "sorting":
  var map = initCborMap()
  var keys = @[
      toCbor(10),
      toCbor(100),
      toCbor(-1),
      toCbor("z"),
      toCbor("aa"),
      toCbor([toCbor(100)]),
      toCbor([toCbor(-1)]),
      toCbor(false),
    ]
  shuffle(keys)
  for k in keys: map[k] = toCbor(0)
  check not map.isSorted
  sort(map)
  check map.isSorted
