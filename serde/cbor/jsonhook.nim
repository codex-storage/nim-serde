# This file is a modified version of Emery Hemingway’s CBOR library for Nim,
# originally available at https://github.com/ehmry/cbor-nim and released under The Unlicense.

import std/[base64, tables]
import ../json/stdjson
import ./types
import ./errors
import ./deserializer

proc toJson*(n: CborNode): JsonNode {.raises: [CborParseError].} =
  case n.kind
  of cborUnsigned:
    newJInt n.uint.BiggestInt
  of cborNegative:
    newJInt n.int.BiggestInt
  of cborBytes:
    newJString base64.encode(cast[string](n.bytes), safe = true)
  of cborText:
    newJString n.text
  of cborArray:
    let a = newJArray()
    for e in n.seq.items:
      a.add(e.toJson)
    a
  of cborMap:
    let o = newJObject()
    for k, v in n.map.pairs:
      if k.kind == cborText:
        o[k.text] = v.toJson
      else:
        o[$k] = v.toJson
    o
  of cborTag:
    nil
  of cborSimple:
    if n.isBool:
      newJBool(n.getBool())
    elif n.isNull:
      newJNull()
    else:
      nil
  of cborFloat:
    newJFloat n.float
  of cborRaw:
    toJson(parseCbor(n.raw))
