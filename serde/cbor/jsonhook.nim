import std/[base64, tables]
import ../json/stdjson
import ./types
import ./errors
import ./deserializer

proc toJsonHook*(n: CborNode): JsonNode =
  case n.kind:
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
        a.add(e.toJsonHook)
      a
    of cborMap:
      let o = newJObject()
      for k, v in n.map.pairs:
        if k.kind == cborText:
          o[k.text] = v.toJsonHook
        else:
          o[$k] = v.toJsonHook
      o
    of cborTag: nil
    of cborSimple:
      if n.isBool:
        newJBool(n.getBool())
      elif n.isNull:
        newJNull()
      else: nil
    of cborFloat:
      newJFloat n.float
    of cborRaw:
      without parsed =? parseCbor(n.raw), error:
        raise newCborError(error.msg)
      toJsonHook(parsed)
