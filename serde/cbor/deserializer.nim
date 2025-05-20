import std/[math, streams, options, tables, strutils, times, typetraits]
import ./types
import ./helpers
import ../utils/types
import ./errors
import pkg/questionable
import pkg/questionable/results

export results
export types


func isIndefinite*(c: CborParser): bool {.inline.} = c.minor == 31
  ## Return true if the parser is positioned on an item of indefinite length.

{.push raises: [].}
proc open*(c: var CborParser; s: Stream) =
  ## Begin parsing a stream of CBOR in binary form.
  ## The parser will be initialized in an EOF state, call
  ## ``next`` to advance it before parsing.
  c.s = s
  c.kind = cborEof
  c.intVal = 0

proc next*(c: var CborParser): ?!void =
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
      of 0..23:
        c.intVal = c.minor.uint64
      of 24:
        c.intVal = c.s.readChar.uint64
      of 25:
        c.intVal = c.s.readChar.uint64
        c.intVal = (c.intVal shl 8) or c.s.readChar.uint64
      of 26:
        c.intVal = c.s.readChar.uint64
        for _ in 1..3:
          {.unroll.}
          c.intVal = (c.intVal shl 8) or c.s.readChar.uint64
      of 27:
        c.intVal = c.s.readChar.uint64
        for _ in 1..7:
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
        return failure(newCborError("unhandled major type " & $mb))
    success()
  except IOError as e:
    return failure(e)
  except OSError as e:
    return failure(e)

proc nextUInt*(c: var CborParser): ?!BiggestUInt =
  ## Parse the integer value that the parser is positioned on.
  if c.kind != CborEventKind.cborPositive:
    return failure(newCborError("Expected positive integer, got " & $c.kind))
  let val = c.intVal.BiggestUInt
  let nextRes = c.next()
  if nextRes.isFailure:
    return failure(nextRes.error)
  return success(val)


proc nextInt*(c: var CborParser): ?!BiggestInt =
  ## Parse the integer value that the parser is positioned on.
  var val: BiggestInt
  case c.kind
  of CborEventKind.cborPositive:
    val = c.intVal.BiggestInt
  of CborEventKind.cborNegative:
    val = -1.BiggestInt - c.intVal.BiggestInt
  else:
    return failure(newCborError("Expected integer, got " & $c.kind))

  let nextRes = c.next()
  if nextRes.isFailure:
    return failure(nextRes.error)

  return success(val)

proc nextFloat*(c: var CborParser): ?!float64 =
  ## Parse the float value that the parser is positioned on.
  var val: float64
  if c.kind != CborEventKind.cborFloat:
    return failure(newCborError("Expected float, got " & $c.kind))
  case c.minor
  of 25:
    val = floatSingle(c.intVal.uint16).float64
  of 26:
    val = cast[float32](c.intVal).float64
  of 27:
    val = cast[float64](c.intVal)
  else:
    discard

  let nextRes = c.next()
  if nextRes.isFailure:
    return failure(nextRes.error)

  return success(val)

func bytesLen*(c: CborParser): ?!int =
  ## Return the length of the byte string that the parser is positioned on.
  if c.kind != CborEventKind.cborBytes:
    return failure(newCborError("Expected bytes, got " & $c.kind))
  return success(c.intVal.int)

template tryNext(c: var CborParser) =
  let nextRes = c.next()
  if nextRes.isFailure:
    return failure(nextRes.error)

template trySkip(c: var CborParser) =
  let skipRes = c.skipNode()
  if skipRes.isFailure:
    return failure(skipRes.error)

proc nextBytes*(c: var CborParser; buf: var openArray[byte]): ?!void =
  ## Read the bytes that the parser is positioned on and advance.
  try:
    if c.kind != CborEventKind.cborBytes:
      return failure(newCborError("Expected bytes, got " & $c.kind))
    if buf.len != c.intVal.int:
      return failure(newCborError("Buffer length mismatch: expected " &
          $c.intVal.int & ", got " & $buf.len))
    if buf.len > 0:
      let n = c.s.readData(buf[0].addr, buf.len)
      if n != buf.len:
        return failure(newCborError("truncated read of CBOR data"))
    tryNext(c)
    success()
  except OSError as e:
    return failure(e.msg)
  except IOError as e:
    return failure(e.msg)

proc nextBytes*(c: var CborParser): ?!seq[byte] =
  ## Read the bytes that the parser is positioned on into a seq and advance.
  var val = newSeq[byte](c.intVal.int)
  let nextRes = nextBytes(c, val)
  if nextRes.isFailure:
    return failure(nextRes.error)

  return success(val)

func textLen*(c: CborParser): ?!int =
  ## Return the length of the text that the parser is positioned on.
  if c.kind != CborEventKind.cborText:
    return failure(newCborError("Expected text, got " & $c.kind))
  return success(c.intVal.int)

proc nextText*(c: var CborParser; buf: var string): ?!void =
  ## Read the text that the parser is positioned on into a string and advance.
  try:
    if c.kind != CborEventKind.cborText:
      return failure(newCborError("Expected text, got " & $c.kind))
    buf.setLen c.intVal.int
    if buf.len > 0:
      let n = c.s.readData(buf[0].addr, buf.len)
      if n != buf.len:
        return failure(newCborError("truncated read of CBOR data"))
    tryNext(c)
    success()
  except IOError as e:
    return failure(e.msg)
  except OSError as e:
    return failure(e.msg)


proc nextText*(c: var CborParser): ?!string =
  ## Read the text that the parser is positioned on into a string and advance.
  var buf: string
  let nextRes = nextText(c, buf)
  if nextRes.isFailure:
    return failure(nextRes.error)

  return success(buf)

func arrayLen*(c: CborParser): int =
  ## Return the length of the array that the parser is positioned on.
  assert(c.kind == CborEventKind.cborArray, $c.kind)
  c.intVal.int

func mapLen*(c: CborParser): int =
  ## Return the length of the map that the parser is positioned on.
  assert(c.kind == CborEventKind.cborMap, $c.kind)
  c.intVal.int

func tag*(c: CborParser): uint64 =
  ## Return the tag value the parser is positioned on.
  assert(c.kind == CborEventKind.cborTag, $c.kind)
  c.intVal

proc skipNode*(c: var CborParser): ?!void =
  ## Skip the item the parser is positioned on.
  try:
    case c.kind
    of CborEventKind.cborEof:
      return failure(newCborError("end of CBOR stream"))
    of CborEventKind.cborPositive, CborEventKind.cborNegative,
        CborEventKind.cborSimple:
      return c.next()
    of CborEventKind.cborBytes, CborEventKind.cborText:
      if c.isIndefinite:
        tryNext(c)
        while c.kind != CborEventKind.cborBreak:
          if c.kind != CborEventKind.cborBytes:
            return failure(newCborError("expected bytes, got " & $c.kind))
          for _ in 1..c.intVal.int: discard readChar(c.s)
          return c.next()
      else:
        for _ in 1..c.intVal.int: discard readChar(c.s)
        return c.next()
    of CborEventKind.cborArray:
      if c.isIndefinite:
        tryNext(c)
        while c.kind != CborEventKind.cborBreak:
          trySkip(c)
        return c.next()
      else:
        let len = c.intVal
        tryNext(c)
        for i in 1..len:
          trySkip(c)
    of CborEventKind.cborMap:
      let mapLen = c.intVal.int
      if c.isIndefinite:
        tryNext(c)
        while c.kind != CborEventKind.cborBreak:
          trySkip(c)
        return c.next()
      else:
        tryNext(c)
        for _ in 1 .. mapLen:
          trySkip(c)
    of CborEventKind.cborTag:
      tryNext(c)
      return c.skipNode()
    of CborEventKind.cborFloat:
      without f =? c.nextFloat(), error:
        return failure(error)
    of CborEventKind.cborBreak:
      discard
    success()
  except OSError as e:
    return failure(e.msg)
  except IOError as e:
    return failure(e.msg)



proc nextNode*(c: var CborParser): ?!CborNode =
  ## Parse the item the parser is positioned on into a ``CborNode``.
  ## This is cheap for numbers or simple values but expensive
  ## for nested types.
  try:
    var next: CborNode
    case c.kind
    of CborEventKind.cborEof:
      return failure(newCborError("end of CBOR stream"))
    of CborEventKind.cborPositive:
      next = CborNode(kind: cborUnsigned, uint: c.intVal)
      tryNext(c)
    of CborEventKind.cborNegative:
      next = CborNode(kind: cborNegative, int: -1 - c.intVal.int64)
      tryNext(c)
    of CborEventKind.cborBytes:
      if c.isIndefinite:
        next = CborNode(kind: cborBytes, bytes: newSeq[byte]())
        tryNext(c)
        while c.kind != CborEventKind.cborBreak:
          if c.kind != CborEventKind.cborBytes:
            return failure(newCborError("Expected bytes, got " & $c.kind))
          let
            chunkLen = c.intVal.int
            pos = next.bytes.len
          next.bytes.setLen(pos+chunkLen)
          let n = c.s.readData(next.bytes[pos].addr, chunkLen)
          if n != chunkLen:
            return failure(newCborError("truncated read of CBOR data"))
          tryNext(c)
      else:
        without rawBytes =? c.nextBytes(), error:
          return failure(error)
        next = CborNode(kind: cborBytes, bytes: rawBytes)
    of CborEventKind.cborText:
      if c.isIndefinite:
        next = CborNode(kind: cborText, text: "")
        tryNext(c)
        while c.kind != CborEventKind.cborBreak:
          if c.kind != CborEventKind.cborText:
            return failure(newCborError("Expected text, got " & $c.kind))
          let
            chunkLen = c.intVal.int
            pos = next.text.len
          next.text.setLen(pos+chunkLen)
          let n = c.s.readData(next.text[pos].addr, chunkLen)
          if n != chunkLen:
            return failure(newCborError("truncated read of CBOR data"))
          tryNext(c)
        tryNext(c)
      else:
        without text =? c.nextText(), error:
          return failure(error)
        next = CborNode(kind: cborText, text: text)
    of CborEventKind.cborArray:
      next = CborNode(kind: cborArray, seq: newSeq[CborNode](c.intVal))
      if c.isIndefinite:
        tryNext(c)
        while c.kind != CborEventKind.cborBreak:
          without node =? c.nextNode(), error:
            return failure(error)
          next.seq.add(node)
        tryNext(c)
      else:
        tryNext(c)
        for i in 0..next.seq.high:
          without node =? c.nextNode(), error:
            return failure(error)
          next.seq[i] = node
    of CborEventKind.cborMap:
      let mapLen = c.intVal.int
      next = CborNode(kind: cborMap, map: initOrderedTable[CborNode, CborNode](
          mapLen.nextPowerOfTwo))
      if c.isIndefinite:
        tryNext(c)
        while c.kind != CborEventKind.cborBreak:
          without key =? c.nextNode(), error:
            return failure(error)
          without val =? c.nextNode(), error:
            return failure(error)
          next.map[key] = val
        tryNext(c)
      else:
        tryNext(c)
        for _ in 1 .. mapLen:
          without key =? c.nextNode(), error:
            return failure(error)
          without val =? c.nextNode(), error:
            return failure(error)
          next.map[key] = val
    of CborEventKind.cborTag:
      let tag = c.intVal
      tryNext(c)
      without node =? c.nextNode(), error:
        return failure(error)
      next = node
      next.tag = some tag
    of CborEventKind.cborSimple:
      case c.minor
      of 24:
        next = CborNode(kind: cborSimple, simple: c.intVal.uint8)
      else:
        next = CborNode(kind: cborSimple, simple: c.minor)
      tryNext(c)
    of CborEventKind.cborFloat:
      without f =? c.nextFloat(), error:
        return failure(error)
      next = CborNode(kind: cborFloat, float: f)
    of CborEventKind.cborBreak:
      discard
    success(next)
  except OSError as e:
    return failure(e.msg)
  except IOError as e:
    return failure(e.msg)
  except Exception as e:
    return failure(e.msg)


proc readCbor*(s: Stream): ?!CborNode =
  ## Parse a stream into a CBOR object.
  var parser: CborParser
  parser.open(s)
  tryNext(parser)
  parser.nextNode()

proc parseCbor*(s: string): ?!CborNode =
  ## Parse a string into a CBOR object.
  ## A wrapper over stream parsing.
  readCbor(newStringStream s)

proc `$`*(n: CborNode): string =
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
    for i in 0..<n.seq.high:
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
    of 20: result.add "false"
    of 21: result.add "true"
    of 22: result.add "null"
    of 23: result.add "undefined"
    of 31: discard # break code for indefinite-length items
    else: result.add "simple(" & $n.simple & ")"
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
    without val =? parseCbor(n.raw), error:
      return error.msg
    result.add $val
  if n.tag.isSome:
    result.add(")")


proc getInt*(n: CborNode; default: int = 0): int =
  ## Get the numerical value of a ``CborNode`` or a fallback.
  case n.kind
  of cborUnsigned: n.uint.int
  of cborNegative: n.int.int
  else: default

proc parseDateText(n: CborNode): DateTime {.raises: [TimeParseError].} =
  parse(n.text, timeFormat)

proc parseTime(n: CborNode): Time =
  case n.kind
  of cborUnsigned, cborNegative:
    result = fromUnix n.getInt
  of cborFloat:
    result = fromUnixFloat n.float
  else:
    assert false

proc fromCborHook*(v: var DateTime; n: CborNode): bool =
  ## Parse a `DateTime` from the tagged string representation
  ## defined in RCF7049 section 2.4.1.
  if n.tag.isSome:
    try:
      if n.tag.get == 0 and n.kind == cborText:
        v = parseDateText(n)
        result = true
      elif n.tag.get == 1 and n.kind in {cborUnsigned, cborNegative, cborFloat}:
        v = parseTime(n).utc
        result = true
    except ValueError: discard

proc fromCborHook*(v: var Time; n: CborNode): bool =
  ## Parse a `Time` from the tagged string representation
  ## defined in RCF7049 section 2.4.1.
  if n.tag.isSome:
    try:
      if n.tag.get == 0 and n.kind == cborText:
        v = parseDateText(n).toTime
        result = true
      elif n.tag.get == 1 and n.kind in {cborUnsigned, cborNegative, cborFloat}:
        v = parseTime(n)
        result = true
    except ValueError: discard

func isTagged*(n: CborNode): bool =
  ## Check if a CBOR item has a tag.
  n.tag.isSome

func hasTag*(n: CborNode; tag: Natural): bool =
  ## Check if a CBOR item has a tag.
  n.tag.isSome and n.tag.get == (uint64)tag

proc `tag=`*(result: var CborNode; tag: Natural) =
  ## Tag a CBOR item.
  result.tag = some(tag.uint64)

func tag*(n: CborNode): uint64 =
  ## Get a CBOR item tag.
  n.tag.get

func isBool*(n: CborNode): bool =
  (n.kind == cborSimple) and (n.simple in {20, 21})

func getBool*(n: CborNode; default = false): bool =
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

proc getUnsigned*(n: CborNode; default: uint64 = 0): uint64 =
  ## Get the numerical value of a ``CborNode`` or a fallback.
  case n.kind
  of cborUnsigned: n.uint
  of cborNegative: n.int.uint64
  else: default

proc getSigned*(n: CborNode; default: int64 = 0): int64 =
  ## Get the numerical value of a ``CborNode`` or a fallback.
  case n.kind
  of cborUnsigned: n.uint.int64
  of cborNegative: n.int
  else: default


func getFloat*(n: CborNode; default = 0.0): float =
  ## Get the floating-poing value of a ``CborNode`` or a fallback.
  if n.kind == cborFloat:
    n.float
  else:
    default


proc fromCbor*[T](v: var T; n: CborNode): ?!void =
  ## Return a Result containing the value if `v` can be converted from a given `CborNode`,
  ## or an error if conversion fails.
  ## Can be extended and overriden with `fromCborHook(v: var T; n: CborNode)`
  ## for specific types of `T`.
  try:
    when T is CborNode:
      v = n
      result = success()
    elif compiles(fromCborHook(v, n)):
      return fromCborHook(v, n)
    elif T is distinct:
      return fromCbor(distinctBase v, n)
    elif T is SomeUnsignedInt:
      exceptCborKind(T, {cborUnsigned}, n)
      v = T n.uint
      if v.BiggestUInt == n.uint:
        return success()
      else:
        return failure(newCborError("Value overflow for unsigned integer"))
    elif T is SomeSignedInt:
      exceptCborKind(T, {cborUnsigned, cborNegative}, n)
      if n.kind == cborUnsigned:
        v = T n.uint
        if v.BiggestUInt == n.uint:
          return success()
        else:
          return failure(newCborError("Value overflow for un signed integer"))
      elif n.kind == cborNegative:
        v = T n.int
        if v.BiggestInt == n.int:
          return success()
        else:
          return failure(newCborError("Value overflow for signed integer"))
    elif T is bool:
      if not n.isBool:
        return failure(newCborError("Expected boolean, got " & $n.kind))
      v = n.getBool
      return success()
    elif T is SomeFloat:
      exceptCborKind(T, {cborFloat}, n)
      v = T n.float
      return success()
    elif T is seq[byte]:
      exceptCborKind(T, {cborBytes}, n)
      v = n.bytes
      return success()
    elif T is string:
      exceptCborKind(T, {cborText}, n)
      v = n.text
      return success()
    elif T is seq:
      exceptCborKind(T, {cborArray}, n)
      v.setLen n.seq.len
      for i, e in n.seq:
        let itemResult = fromCbor(v[i], e)
        if itemResult.isFailure:
          v.setLen 0
          return failure(itemResult.error)
      return success()
    elif T is tuple:
      exceptCborKind(T, {cborArray}, n)
      if n.seq.len != T.tupleLen:
        return failure(newCborError("Expected tuple of length " & $T.tupleLen))
      var i: int
      for f in fields(v):
        let itemResult = fromCbor(f, n.seq[i])
        if itemResult.isFailure:
          return failure(itemResult.error)
        inc i
      return success()
    elif T is ref:
      if n.isNull:
        v = nil
        return success()
      else:
        if isNil(v): new(v)
        return fromCbor(v[], n)
    elif T is object:
      exceptCborKind(T, {cborMap}, n)
      var
        i: int
        key = CborNode(kind: cborText)
      for s, _ in fieldPairs(v):
        key.text = s
        if not n.map.hasKey key:
          return failure(newCborError("Missing field: " & s))
        else:
          let fieldResult = fromCbor(v.dot(s), n.map[key])
          if fieldResult.isFailure:
            return failure(fieldResult.error)
          inc i
      if i == n.map.len:
        return success()
      else:
        return failure(newCborError("Extra fields in map"))
    else:
      return failure(newCborError("Unsupported type: " & $T))
  except Exception as e:
    return failure(newCborError(e.msg))
