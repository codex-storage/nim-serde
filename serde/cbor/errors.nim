# This file is a modified version of Emery Hemingway’s CBOR library for Nim,
# originally available at https://github.com/ehmry/cbor-nim and released under The Unlicense.

import ../utils/types
import ./types
import std/sets

proc newUnexpectedKindError*(
    expectedType: type, expectedKinds: string, cbor: CborNode
): ref UnexpectedKindError =
  newException(
    UnexpectedKindError,
    "deserialization to " & $expectedType & " failed: expected " &
    expectedKinds &
      " but got " & $cbor.kind,
  )

proc newUnexpectedKindError*(
    expectedType: type, expectedKinds: set[CborEventKind], cbor: CborNode
): ref UnexpectedKindError =
  newUnexpectedKindError(expectedType, $expectedKinds, cbor)

proc newUnexpectedKindError*(
    expectedType: type, expectedKind: CborEventKind, cbor: CborNode
): ref UnexpectedKindError =
  newUnexpectedKindError(expectedType, {expectedKind}, cbor)

proc newUnexpectedKindError*(
    expectedType: type, expectedKinds: set[CborNodeKind], cbor: CborNode
): ref UnexpectedKindError =
  newUnexpectedKindError(expectedType, $expectedKinds, cbor)

proc newUnexpectedKindError*(
    expectedType: type, expectedKind: CborNodeKind, cbor: CborNode
): ref UnexpectedKindError =
  newUnexpectedKindError(expectedType, {expectedKind}, cbor)

proc newCborError*(msg: string): ref CborParseError =
  newException(CborParseError, msg)
