# This file is a modified version of Emery Hemingway’s CBOR library for Nim,
# originally available at https://github.com/ehmry/cbor-nim and released under The Unlicense.

import ./types
import ./errors
from macros import newDotExpr, newIdentNode, strVal

template expectCborKind*(expectedType: type, expectedKinds: set[CborNodeKind],
    cbor: CborNode) =
  if cbor.kind notin expectedKinds:
    return failure(newUnexpectedKindError(expectedType, expectedKinds, cbor))

template expectCborKind*(expectedType: type, expectedKind: CborNodeKind,
    cbor: CborNode) =
  expectCborKind(expectedType, {expectedKind}, cbor)

template expectCborKind*(expectedType: type, expectedKinds: set[CborEventKind],
    cbor: CborNode) =
  if cbor.kind notin expectedKinds:
    return failure(newUnexpectedKindError(expectedType, expectedKinds, cbor))

template expectCborKind*(expectedType: type, expectedKind: CborEventKind,
    cbor: CborNode) =
  expectCborKind(expectedType, {expectedKind}, cbor)

macro dot*(obj: object, fld: string): untyped =
  ## Turn ``obj.dot("fld")`` into ``obj.fld``.
  newDotExpr(obj, newIdentNode(fld.strVal))

func floatSingle*(half: uint16): float32 =
  ## Convert a 16-bit float to 32-bits.
  func ldexp(x: float64; exponent: int): float64 {.importc: "ldexp",
        header: "<math.h>".}
  let
    exp = (half shr 10) and 0x1f
    mant = float64(half and 0x3ff)
    val = if exp == 0:
        ldexp(mant, -24)
      elif exp != 31:
        ldexp(mant + 1024, exp.int - 25)
      else:
        if mant == 0: Inf else: NaN
  if (half and 0x8000) == 0: val else: -val
