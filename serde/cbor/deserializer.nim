# This file is a modified version of Emery Hemingway’s CBOR library for Nim,
# originally available at https://github.com/ehmry/cbor-nim and released under The Unlicense.

import std/[math, streams, options, tables, strutils, times, typetraits, macros]
import ./types as cborTypes
import ./helpers
import ../utils/types
import ../utils/pragmas
import ./errors
import pkg/questionable
import pkg/questionable/results

export results
export types
export pragmas
export cborTypes
export macros

{.push raises: [].}

func isIndefinite*(c: CborParser): bool {.inline.} =
  ## Return true if the parser is positioned on an item of indefinite length.
  c.minor == 31

proc open*(c: var CborParser, s: Stream) =
  ## Begin parsing a stream of CBOR in binary form.
  ## The parser will be initialized in an EOF state, call
  ## ``next`` to advance it before parsing.
  c.s = s
  c.kind = cborEof
  c.intVal = 0

proc next*(c: var CborParser) {.raises: [CborParseError].} =
  ## Advance the parser to the initial or next event.
  try:
    if c.s.atEnd:
      c.kind = CborEventKind.cborEof
      c.intVal = 0
    else:
      let
        ib = c.s.readUint8
        mb = ib shr 5
      c.minor = ib and 0b11111
      case c.minor
      of 0 .. 23:
        c.intVal = c.minor.uint64
      of 24:
        c.intVal = c.s.readChar.uint64
      of 25:
        c.intVal = c.s.readChar.uint64
        c.intVal = (c.intVal shl 8) or c.s.readChar.uint64
      of 26:
        c.intVal = c.s.readChar.uint64
        for _ in 1 .. 3:
          {.unroll.}
          c.intVal = (c.intVal shl 8) or c.s.readChar.uint64
      of 27:
        c.intVal = c.s.readChar.uint64
        for _ in 1 .. 7:
          {.unroll.}
          c.intVal = (c.intVal shl 8) or c.s.readChar.uint64
      else:
        c.intVal = 0
      case mb
      of PositiveMajor:
        c.kind = CborEventKind.cborPositive
      of NegativeMajor:
        c.kind = CborEventKind.cborNegative
      of BytesMajor:
        c.kind = CborEventKind.cborBytes
      of TextMajor:
        c.kind = CborEventKind.cborText
      of ArrayMajor:
        c.kind = CborEventKind.cborArray
      of MapMajor:
        c.kind = CborEventKind.cborMap
      of TagMajor:
        c.kind = CborEventKind.cborTag
      of SimpleMajor:
        if c.minor in {25, 26, 27}:
          c.kind = CborEventKind.cborFloat
        elif c.isIndefinite:
          c.kind = CborEventKind.cborBreak
        else:
          c.kind = CborEventKind.cborSimple
      else:
        raise newCborError("unhandled major type " & $mb)
  except IOError as e:
    raise newException(CborParseError, e.msg, e)
  except OSError as e:
    raise newException(CborParseError, e.msg, e)

proc nextUInt*(c: var CborParser): BiggestUInt {.raises: [CborParseError].} =
  ## Parse the integer value that the parser is positioned on.
  parseAssert(
    c.kind == CborEventKind.cborPositive, "Expected positive integer, got " & $c.kind
  )
  result = c.intVal.BiggestUInt

  c.next()

proc nextInt*(c: var CborParser): BiggestInt {.raises: [CborParseError].} =
  ## Parse the integer value that the parser is positioned on.
  case c.kind
  of CborEventKind.cborPositive:
    result = c.intVal.BiggestInt
  of CborEventKind.cborNegative:
    result = -1.BiggestInt - c.intVal.BiggestInt
  else:
    raise newCborError("Expected integer, got " & $c.kind)

  c.next()

proc nextFloat*(c: var CborParser): float64 {.raises: [CborParseError].} =
  ## Parse the float value that the parser is positioned on.
  parseAssert(c.kind == CborEventKind.cborFloat, "Expected float, got " & $c.kind)
  case c.minor
  of 25:
    result = floatSingle(c.intVal.uint16).float64
  of 26:
    result = cast[float32](c.intVal).float64
  of 27:
    result = cast[float64](c.intVal)
  else:
    discard

  c.next()

func bytesLen*(c: CborParser): int {.raises: [CborParseError].} =
  ## Return the length of the byte string that the parser is positioned on.
  parseAssert(c.kind == CborEventKind.cborBytes, "Expected bytes, got " & $c.kind)
  c.intVal.int

proc nextBytes*(
    c: var CborParser, buf: var openArray[byte]
) {.raises: [CborParseError].} =
  ## Read the bytes that the parser is positioned on and advance.
  try:
    parseAssert(c.kind == CborEventKind.cborBytes, "Expected bytes, got " & $c.kind)
    parseAssert(
      buf.len == c.intVal.int,
      "Buffer length mismatch: expected " & $c.intVal.int & ", got " & $buf.len,
    )
    if buf.len > 0:
      let n = c.s.readData(buf[0].addr, buf.len)
      parseAssert(n == buf.len, "truncated read of CBOR data")
    c.next()
  except OSError as e:
    raise newException(CborParseError, e.msg, e)
  except IOError as e:
    raise newException(CborParseError, e.msg, e)

proc nextBytes*(c: var CborParser): seq[byte] {.raises: [CborParseError].} =
  ## Read the bytes that the parser is positioned on into a seq and advance.
  result = newSeq[byte](c.intVal.int)
  nextBytes(c, result)

func textLen*(c: CborParser): int {.raises: [CborParseError].} =
  ## Return the length of the text that the parser is positioned on.
  parseAssert(c.kind == CborEventKind.cborText, "Expected text, got " & $c.kind)
  c.intVal.int

proc nextText*(c: var CborParser, buf: var string) {.raises: [CborParseError].} =
  ## Read the text that the parser is positioned on into a string and advance.
  try:
    parseAssert(c.kind == CborEventKind.cborText, "Expected text, got " & $c.kind)
    buf.setLen c.intVal.int
    if buf.len > 0:
      let n = c.s.readData(buf[0].addr, buf.len)
      parseAssert(n == buf.len, "truncated read of CBOR data")
    c.next()
  except IOError as e:
    raise newException(CborParseError, e.msg, e)
  except OSError as e:
    raise newException(CborParseError, e.msg, e)

proc nextText*(c: var CborParser): string {.raises: [CborParseError].} =
  ## Read the text that the parser is positioned on into a string and advance.
  nextText(c, result)

func arrayLen*(c: CborParser): int {.raises: [CborParseError].} =
  ## Return the length of the array that the parser is positioned on.
  parseAssert(c.kind == CborEventKind.cborArray, "Expected array, got " & $c.kind)
  c.intVal.int

func mapLen*(c: CborParser): int {.raises: [CborParseError].} =
  ## Return the length of the map that the parser is positioned on.
  parseAssert(c.kind == CborEventKind.cborMap, "Expected map, got " & $c.kind)
  c.intVal.int

func tag*(c: CborParser): uint64 {.raises: [CborParseError].} =
  ## Return the tag value the parser is positioned on.
  parseAssert(c.kind == CborEventKind.cborTag, "Expected tag, got " & $c.kind)
  c.intVal

proc skipNode*(c: var CborParser) {.raises: [CborParseError].} =
  ## Skip the item the parser is positioned on.
  try:
    case c.kind
    of CborEventKind.cborEof:
      raise newCborError("end of CBOR stream")
    of CborEventKind.cborPositive, CborEventKind.cborNegative, CborEventKind.cborSimple:
      c.next()
    of CborEventKind.cborBytes, CborEventKind.cborText:
      if c.isIndefinite:
        c.next()
        while c.kind != CborEventKind.cborBreak:
          parseAssert(
            c.kind == CborEventKind.cborBytes, "expected bytes, got " & $c.kind
          )
          for _ in 1 .. c.intVal.int:
            discard readChar(c.s)
          c.next()
      else:
        for _ in 1 .. c.intVal.int:
          discard readChar(c.s)
        c.next()
    of CborEventKind.cborArray:
      if c.isIndefinite:
        c.next()
        while c.kind != CborEventKind.cborBreak:
          c.skipNode()
        c.next()
      else:
        let len = c.intVal
        c.next()
        for i in 1 .. len:
          c.skipNode()
    of CborEventKind.cborMap:
      let mapLen = c.intVal.int
      if c.isIndefinite:
        c.next()
        while c.kind != CborEventKind.cborBreak:
          c.skipNode()
        c.next()
      else:
        c.next()
        for _ in 1 .. mapLen:
          c.skipNode()
    of CborEventKind.cborTag:
      c.next()
      c.skipNode()
    of CborEventKind.cborFloat:
      discard c.nextFloat()
    of CborEventKind.cborBreak:
      discard
  except OSError as os:
    raise newException(CborParseError, os.msg, os)
  except IOError as io:
    raise newException(CborParseError, io.msg, io)

proc nextNode*(c: var CborParser): CborNode {.raises: [CborParseError].} =
  ## Parse the item the parser is positioned on into a ``CborNode``.
  ## This is cheap for numbers or simple values but expensive
  ## for nested types.
  try:
    case c.kind
    of CborEventKind.cborEof:
      raise newCborError("end of CBOR stream")
    of CborEventKind.cborPositive:
      result = CborNode(kind: cborUnsigned, uint: c.intVal)
      c.next()
    of CborEventKind.cborNegative:
      result = CborNode(kind: cborNegative, int: -1 - c.intVal.int64)
      c.next()
    of CborEventKind.cborBytes:
      if c.isIndefinite:
        result = CborNode(kind: cborBytes, bytes: newSeq[byte]())
        c.next()
        while c.kind != CborEventKind.cborBreak:
          parseAssert(
            c.kind == CborEventKind.cborBytes, "Expected bytes, got " & $c.kind
          )
          let
            chunkLen = c.intVal.int
            pos = result.bytes.len
          result.bytes.setLen(pos + chunkLen)
          let n = c.s.readData(result.bytes[pos].addr, chunkLen)
          parseAssert(n == chunkLen, "truncated read of CBOR data")
          c.next()
      else:
        result = CborNode(kind: cborBytes, bytes: c.nextBytes())
    of CborEventKind.cborText:
      if c.isIndefinite:
        result = CborNode(kind: cborText, text: "")
        c.next()
        while c.kind != CborEventKind.cborBreak:
          parseAssert(c.kind == CborEventKind.cborText, "Expected text, got " & $c.kind)
          let
            chunkLen = c.intVal.int
            pos = result.text.len
          result.text.setLen(pos + chunkLen)
          let n = c.s.readData(result.text[pos].addr, chunkLen)
          parseAssert(n == chunkLen, "truncated read of CBOR data")
          c.next()
        c.next()
      else:
        result = CborNode(kind: cborText, text: c.nextText())
    of CborEventKind.cborArray:
      result = CborNode(kind: cborArray, seq: newSeq[CborNode](c.intVal))
      if c.isIndefinite:
        c.next()
        while c.kind != CborEventKind.cborBreak:
          result.seq.add(c.nextNode())
        c.next()
      else:
        c.next()
        for i in 0 .. result.seq.high:
          result.seq[i] = c.nextNode()
    of CborEventKind.cborMap:
      let mapLen = c.intVal.int
      result = CborNode(
        kind: cborMap, map: initOrderedTable[CborNode, CborNode](mapLen.nextPowerOfTwo)
      )
      if c.isIndefinite:
        c.next()
        while c.kind != CborEventKind.cborBreak:
          result.map[c.nextNode()] = c.nextNode()
        c.next()
      else:
        c.next()
        for _ in 1 .. mapLen:
          result.map[c.nextNode()] = c.nextNode()
    of CborEventKind.cborTag:
      let tag = c.intVal
      c.next()
      result = c.nextNode()
      result.tag = some tag
    of CborEventKind.cborSimple:
      case c.minor
      of 24:
        result = CborNode(kind: cborSimple, simple: c.intVal.uint8)
      else:
        result = CborNode(kind: cborSimple, simple: c.minor)
      c.next()
    of CborEventKind.cborFloat:
      result = CborNode(kind: cborFloat, float: c.nextFloat())
    of CborEventKind.cborBreak:
      discard
  except OSError as e:
    raise newException(CborParseError, e.msg, e)
  except IOError as e:
    raise newException(CborParseError, e.msg, e)
  except CatchableError as e:
    raise newException(CborParseError, e.msg, e)
  except Exception as e:
    raise newException(Defect, e.msg, e)

proc readCbor*(s: Stream): CborNode {.raises: [CborParseError].} =
  ## Parse a stream into a CBOR object.
  var parser: CborParser
  parser.open(s)
  parser.next()
  parser.nextNode()

proc parseCbor*(s: string): CborNode {.raises: [CborParseError].} =
  ## Parse a string into a CBOR object.
  ## A wrapper over stream parsing.
  readCbor(newStringStream s)

proc `$`*(n: CborNode): string {.raises: [CborParseError].} =
  ## Get a ``CborNode`` in diagnostic notation.
  result = ""
  if n.tag.isSome:
    result.add($n.tag.get)
    result.add("(")
  case n.kind
  of cborUnsigned:
    result.add $n.uint
  of cborNegative:
    result.add $n.int
  of cborBytes:
    result.add "h'"
    for c in n.bytes:
      result.add(c.toHex)
    result.add "'"
  of cborText:
    result.add escape n.text
  of cborArray:
    result.add "["
    for i in 0 ..< n.seq.high:
      result.add $(n.seq[i])
      result.add ", "
    if n.seq.len > 0:
      result.add $(n.seq[n.seq.high])
    result.add "]"
  of cborMap:
    result.add "{"
    let final = n.map.len
    var i = 1
    for k, v in n.map.pairs:
      result.add $k
      result.add ": "
      result.add $v
      if i != final:
        result.add ", "
      inc i
    result.add "}"
  of cborTag:
    discard
  of cborSimple:
    case n.simple
    of 20:
      result.add "false"
    of 21:
      result.add "true"
    of 22:
      result.add "null"
    of 23:
      result.add "undefined"
    of 31:
      discard
    # break code for indefinite-length items
    else:
      result.add "simple(" & $n.simple & ")"
  of cborFloat:
    case n.float.classify
    of fcNan:
      result.add "NaN"
    of fcInf:
      result.add "Infinity"
    of fcNegInf:
      result.add "-Infinity"
    else:
      result.add $n.float
  of cborRaw:
    result.add $parseCbor(n.raw)
  if n.tag.isSome:
    result.add(")")

proc getInt*(n: CborNode, default: int = 0): int =
  ## Get the numerical value of a ``CborNode`` or a fallback.
  case n.kind
  of cborUnsigned: n.uint.int
  of cborNegative: n.int.int
  else: default

proc parseDateText(n: CborNode): DateTime {.raises: [TimeParseError].} =
  parse(n.text, dateTimeFormat)

proc parseTime(n: CborNode): Time =
  case n.kind
  of cborUnsigned, cborNegative:
    result = fromUnix n.getInt
  of cborFloat:
    result = fromUnixFloat n.float
  else:
    assert false

proc fromCbor*(_: type DateTime, n: CborNode): ?!DateTime =
  ## Parse a `DateTime` from the tagged string representation
  ## defined in RCF7049 section 2.4.1.
  var v: DateTime
  if n.tag.isSome:
    try:
      if n.tag.get == 0 and n.kind == cborText:
        v = parseDateText(n)
        return success(v)
      elif n.tag.get == 1 and n.kind in {cborUnsigned, cborNegative, cborFloat}:
        v = parseTime(n).utc
        return success(v)
    except ValueError as e:
      return failure(e)

proc fromCbor*(_: type Time, n: CborNode): ?!Time =
  ## Parse a `Time` from the tagged string representation
  ## defined in RCF7049 section 2.4.1.
  var v: Time
  if n.tag.isSome:
    try:
      if n.tag.get == 0 and n.kind == cborText:
        v = parseDateText(n).toTime
        return success(v)
      elif n.tag.get == 1 and n.kind in {cborUnsigned, cborNegative, cborFloat}:
        v = parseTime(n)
        return success(v)
    except ValueError as e:
      return failure(e)

func isTagged*(n: CborNode): bool =
  ## Check if a CBOR item has a tag.
  n.tag.isSome

func hasTag*(n: CborNode, tag: Natural): bool =
  ## Check if a CBOR item has a tag.
  n.tag.isSome and n.tag.get == (uint64) tag

proc `tag=`*(result: var CborNode, tag: Natural) =
  ## Tag a CBOR item.
  result.tag = some(tag.uint64)

func tag*(n: CborNode): uint64 =
  ## Get a CBOR item tag.
  n.tag.get

func isBool*(n: CborNode): bool =
  (n.kind == cborSimple) and (n.simple in {20, 21})

func getBool*(n: CborNode, default = false): bool =
  ## Get the boolean value of a ``CborNode`` or a fallback.
  if n.kind == cborSimple:
    case n.simple
    of 20: false
    of 21: true
    else: default
  else:
    default

func isNull*(n: CborNode): bool =
  ## Return true if ``n`` is a CBOR null.
  (n.kind == cborSimple) and (n.simple == 22)

proc getUnsigned*(n: CborNode, default: uint64 = 0): uint64 =
  ## Get the numerical value of a ``CborNode`` or a fallback.
  case n.kind
  of cborUnsigned: n.uint
  of cborNegative: n.int.uint64
  else: default

proc getSigned*(n: CborNode, default: int64 = 0): int64 =
  ## Get the numerical value of a ``CborNode`` or a fallback.
  case n.kind
  of cborUnsigned: n.uint.int64
  of cborNegative: n.int
  else: default

func getFloat*(n: CborNode, default = 0.0): float =
  ## Get the floating-poing value of a ``CborNode`` or a fallback.
  if n.kind == cborFloat: n.float else: default

proc fromCbor*[T: distinct](_: type T, n: CborNode): ?!T =
  success T(?T.distinctBase.fromCbor(n))

proc fromCbor*[T: SomeUnsignedInt](_: type T, n: CborNode): ?!T =
  expectCborKind(T, {cborUnsigned}, n)
  var v = T(n.uint)
  if v.BiggestUInt == n.uint:
    return success(v)
  else:
    return failure(newCborError("Value overflow for unsigned integer"))

proc fromCbor*[T: SomeSignedInt](_: type T, n: CborNode): ?!T =
  expectCborKind(T, {cborUnsigned, cborNegative}, n)
  if n.kind == cborUnsigned:
    var v = T(n.uint)
    if v.BiggestUInt == n.uint:
      return success(v)
    else:
      return failure(newCborError("Value overflow for signed integer"))
  elif n.kind == cborNegative:
    var v = T(n.int)
    if v.BiggestInt == n.int:
      return success(v)
    else:
      return failure(newCborError("Value overflow for signed integer"))

proc fromCbor*[T: SomeFloat](_: type T, n: CborNode): ?!T =
  expectCborKind(T, {cborFloat}, n)
  return success(T(n.float))

proc fromCbor*(_: type seq[byte], n: CborNode): ?!seq[byte] =
  expectCborKind(seq[byte], cborBytes, n)
  return success(n.bytes)

proc fromCbor*(_: type string, n: CborNode): ?!string =
  expectCborKind(string, cborText, n)
  return success(n.text)

proc fromCbor*(_: type bool, n: CborNode): ?!bool =
  if not n.isBool:
    return failure(newCborError("Expected boolean, got " & $n.kind))
  return success(n.getBool)

proc fromCbor*[T](_: type seq[T], n: CborNode): ?!seq[T] =
  expectCborKind(seq[T], cborArray, n)
  var arr = newSeq[T](n.seq.len)
  for i, elem in n.seq:
    arr[i] = ?T.fromCbor(elem)
  success arr

proc fromCbor*[T: tuple](_: type T, n: CborNode): ?!T =
  expectCborKind(T, cborArray, n)
  var res = T.default
  if n.seq.len != T.tupleLen:
    return failure(newCborError("Expected tuple of length " & $T.tupleLen))
  var i: int
  for f in fields(res):
    f = ?typeof(f).fromCbor(n.seq[i])
    inc i

  success res

proc fromCbor*[T: ref](_: type T, n: CborNode): ?!T =
  when T is ref:
    if n.isNull:
      return success(T.default)
    else:
      var resRef = T.new()
      let res = typeof(resRef[]).fromCbor(n)
      if res.isFailure:
        return failure(newCborError(res.error.msg))
      resRef[] = res.value
      return success(resRef)

proc fromCbor*[T: object](_: type T, n: CborNode): ?!T =
  when T is CborNode:
    return success T(n)

  expectCborKind(T, {cborMap}, n)
  var res = T.default

  # Added because serde {serialize, deserialize} pragmas and options are not supported for cbor
  assertNoPragma(T, deserialize, "deserialize pragma not supported")

  try:
    var
      i: int
      key = CborNode(kind: cborText)
    for name, value in fieldPairs(
      when type(T) is ref:
        res[]
      else:
        res
    ):
      assertNoPragma(value, deserialize, "deserialize pragma not supported")

      key.text = name

      if not n.map.hasKey key:
        return failure(newCborError("Missing field: " & name))
      else:
        value = ?typeof(value).fromCbor(n.map[key])
        inc i
    if i == n.map.len:
      return success(res)
    else:
      return failure(newCborError("Extra fields in map"))
  except CatchableError as e:
    return failure newCborError(e.msg)
  except Exception as e:
    raise newException(Defect, e.msg, e)

proc fromCbor*[T: ref object or object](_: type T, str: string): ?!T =
  var n = ?(parseCbor(str)).catch
  T.fromCbor(n)
