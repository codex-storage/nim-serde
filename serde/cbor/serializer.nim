{.push checks: off.}

import std/[streams, options, tables, typetraits, math, endians, times, base64]
import ./types

func isHalfPrecise(single: float32): bool =
  # TODO: check for subnormal false-positives
  let val = cast[uint32](single)
  if val == 0 or val == (1'u32 shl 31):
    result = true
  else:
    let
      exp = int32((val and (0xff'u32 shl 23)) shr 23) - 127
      mant = val and 0x7fffff'u32
    if -25 < exp and exp < 16 and (mant and 0x1fff) == 0:
      result = true

func floatHalf(single: float32): uint16 =
  ## Convert a 32-bit float to 16-bits.
  let
    val = cast[uint32](single)
    exp = val and 0x7f800000
    mant = val and 0x7fffff
    sign = uint16(val shr 16) and (1 shl 15)
  let
    unbiasedExp = int32(exp shr 23) - 127
    halfExp = unbiasedExp + 15
  if halfExp < 1:
    if 14 - halfExp < 25:
      result = sign or uint16((mant or 0x800000) shr uint16(14 - halfExp))
  else:
    result = sign or uint16(halfExp shl 10) or uint16(mant shr 13)

func initialByte(major, minor: Natural): uint8 {.inline.} =
  uint8((major shl 5) or (minor and 0b11111))

proc writeInitial[T: SomeInteger](str: Stream; m: uint8; n: T) =
  ## Write the initial integer of a CBOR item.

  let m = m shl 5
  when T is byte:
    if n < 24:
      str.write(m or n.uint8)
    else:
      str.write(m or 24'u8)
      str.write(n)
  else:
    if n < 24:
      str.write(m or n.uint8)
    elif uint64(n) <= uint64(uint8.high):
      str.write(m or 24'u8)
      str.write(n.uint8)
    elif uint64(n) <= uint64(uint16.high):
      str.write(m or 25'u8)
      str.write((uint8)n shr 8)
      str.write((uint8)n)
    elif uint64(n) <= uint64(uint32.high):
      str.write(m or 26'u8)
      for i in countdown(24, 8, 8):
        {.unroll.}
        str.write((uint8)n shr i)
      str.write((uint8)n)
    else:
      str.write(m or 27'u8)
      for i in countdown(56, 8, 8):
        {.unroll.}
        str.write((uint8)n shr i)
      str.write((uint8)n)
# {.pop.}

proc writeCborArrayLen*(str: Stream; len: Natural) =
  ## Write a marker to the stream that initiates an array of ``len`` items.
  str.writeInitial(4, len)

proc writeCborIndefiniteArrayLen*(str: Stream) =
  ## Write a marker to the stream that initiates an array of indefinite length.
  ## Indefinite length arrays are composed of an indefinite amount of arrays
  ## of definite lengths.
  str.write(initialByte(4, 31))

proc writeCborMapLen*(str: Stream; len: Natural) =
  ## Write a marker to the stream that initiates an map of ``len`` pairs.
  str.writeInitial(5, len)

proc writeCborIndefiniteMapLen*(str: Stream) =
  ## Write a marker to the stream that initiates a map of indefinite length.
  ## Indefinite length maps are composed of an indefinite amount of maps
  ## of definite length.
  str.write(initialByte(5, 31))

proc writeCborBreak*(str: Stream) =
  ## Write a marker to the stream that ends an indefinite array or map.
  str.write(initialByte(7, 31))

proc writeCborTag*(str: Stream; tag: Natural) {.inline.} =
  ## Write a tag for the next CBOR item to a binary stream.
  str.writeInitial(6, tag)

proc writeCbor*(str: Stream; buf: pointer; len: int) =
  ## Write a raw buffer to a CBOR `Stream`.
  str.writeInitial(BytesMajor, len)
  if len > 0: str.writeData(buf, len)

proc isSorted*(n: CborNode): bool {.gcsafe.}

proc writeCbor*[T](str: Stream; v: T) =
  ## Write the CBOR binary representation of a `T` to a `Stream`.
  ## The behavior of this procedure can be extended or overriden
  ## by defining `proc writeCborHook(str: Stream; v: T)` for specific
  ## types `T`.
  when T is CborNode:
    if v.tag.isSome:
      str.writeCborTag(v.tag.get)
    case v.kind:
    of cborUnsigned:
      str.writeCbor(v.uint)
    of cborNegative:
      str.writeCbor(v.int)
    of cborBytes:
      str.writeInitial(cborBytes.uint8, v.bytes.len)
      for b in v.bytes.items:
        str.write(b)
    of cborText:
      str.writeInitial(cborText.uint8, v.text.len)
      str.write(v.text)
    of cborArray:
      str.writeInitial(4, v.seq.len)
      for e in v.seq:
        str.writeCbor(e)
    of cborMap:
      assert(v.isSorted, "refusing to write unsorted map to stream")
      str.writeInitial(5, v.map.len)
      for k, f in v.map.pairs:
        str.writeCbor(k)
        str.writeCbor(f)
    of cborTag:
      discard
    of cborSimple:
      if v.simple > 31'u or v.simple == 24:
        str.write(initialByte(cborSimple.uint8, 24))
        str.write(v.simple)
      else:
        str.write(initialByte(cborSimple.uint8, v.simple))
    of cborFloat:
      str.writeCbor(v.float)
    of cborRaw:
      str.write(v.raw)
  elif compiles(writeCborHook(str, v)):
    writeCborHook(str, v)
  elif T is SomeUnsignedInt:
    str.writeInitial(0, v)
  elif T is SomeSignedInt:
    if v < 0:
      # Major type 1
      str.writeInitial(1, -1 - v)
    else:
      # Major type 0
      str.writeInitial(0, v)
  elif T is seq[byte]:
    str.writeInitial(BytesMajor, v.len)
    if v.len > 0:
      str.writeData(unsafeAddr v[0], v.len)
  elif T is openArray[char | uint8 | int8]:
    str.writeInitial(BytesMajor, v.len)
    if v.len > 0:
      str.writeData(unsafeAddr v[0], v.len)
  elif T is string:
    str.writeInitial(TextMajor, v.len)
    str.write(v)
  elif T is array | seq:
    str.writeInitial(4, v.len)
    for e in v.items:
      writeCbor(str, e)
  elif T is tuple:
    str.writeInitial(4, T.tupleLen)
    for f in v.fields: str.writeCbor(f)
  elif T is ptr | ref:
    if system.`==`(v, nil):
      # Major type 7
      str.write(Null)
    else: writeCbor(str, v[])
  elif T is object:
    var n: uint
    for _, _ in v.fieldPairs:
      inc n
    str.writeInitial(5, n)
    for k, f in v.fieldPairs:
      str.writeCbor(k)
      str.writeCbor(f)
  elif T is bool:
    str.write(initialByte(7, (if v: 21 else: 20)))
  elif T is SomeFloat:
    case v.classify
    of fcNormal, fcSubnormal:
      let single = v.float32
      if single.float64 == v.float64:
        if single.isHalfPrecise:
          let half = floatHalf(single)
          str.write(initialByte(7, 25))
          when system.cpuEndian == bigEndian:
            str.write(half)
          else:
            var be: uint16
            swapEndian16 be.addr, half.unsafeAddr
            str.write(be)
        else:
          str.write initialByte(7, 26)
          when system.cpuEndian == bigEndian:
            str.write(single)
          else:
            var be: uint32
            swapEndian32 be.addr, single.unsafeAddr
            str.write(be)
      else:
        str.write initialByte(7, 27)
        when system.cpuEndian == bigEndian:
          str.write(v)
        else:
          var be: float64
          swapEndian64 be.addr, v.unsafeAddr
          str.write be
      return
    of fcZero:
      str.write initialByte(7, 25)
      str.write((char)0x00)
    of fcNegZero:
      str.write initialByte(7, 25)
      str.write((char)0x80)
    of fcInf:
      str.write initialByte(7, 25)
      str.write((char)0x7c)
    of fcNan:
      str.write initialByte(7, 25)
      str.write((char)0x7e)
    of fcNegInf:
      str.write initialByte(7, 25)
      str.write((char)0xfc)
    str.write((char)0x00)

proc writeCborArray*(str: Stream; args: varargs[CborNode, toCbor]) =
  ## Encode to a CBOR array in binary form. This magic doesn't
  ## always work, some arguments may need to be explicitly
  ## converted with ``toCbor`` before passing.
  str.writeCborArrayLen(args.len)
  for x in args:
    str.writeCbor(x)

proc encode*[T](v: T): string =
  ## Encode an arbitrary value to CBOR binary representation.
  ## A wrapper over ``writeCbor``.
  let s = newStringStream()
  s.writeCbor(v)
  s.data

proc toRaw*(n: CborNode): CborNode =
  ## Reduce a CborNode to a string of bytes.
  if n.kind == cborRaw: n
  else: CborNode(kind: cborRaw, raw: encode(n))

proc isSorted(n: CborNode): bool =
  ## Check if the item is sorted correctly.
  var lastRaw = ""
  for key in n.map.keys:
    let thisRaw = key.toRaw.raw
    if lastRaw != "":
      if cmp(lastRaw, thisRaw) > 0: return false
    lastRaw = thisRaw
  true

proc sort*(n: var CborNode) =
  ## Sort a CBOR map object.
  var tmp = initOrderedTable[CborNode, CborNode](n.map.len.nextPowerOfTwo)
  for key, val in n.map.mpairs:
    tmp[key.toRaw] = move(val)
  sort(tmp) do (x, y: tuple[k: CborNode; v: CborNode]) -> int:
    result = cmp(x.k.raw, y.k.raw)
  n.map = move tmp

proc writeCborHook*(str: Stream; dt: DateTime) =
  ## Write a `DateTime` using the tagged string representation
  ## defined in RCF7049 section 2.4.1.
  writeCborTag(str, 0)
  writeCbor(str, format(dt, timeFormat))

proc writeCborHook*(str: Stream; t: Time) =
  ## Write a `Time` using the tagged numerical representation
  ## defined in RCF7049 section 2.4.1.
  writeCborTag(str, 1)
  writeCbor(str, t.toUnix)

func toCbor*(x: CborNode): CborNode = x

func toCbor*(x: SomeInteger): CborNode =
  if x > 0:
    CborNode(kind: cborUnsigned, uint: x.uint64)
  else:
    CborNode(kind: cborNegative, int: x.int64)

func toCbor*(x: openArray[byte]): CborNode =
  CborNode(kind: cborBytes, bytes: @x)

func toCbor*(x: string): CborNode =
  CborNode(kind: cborText, text: x)

func toCbor*(x: openArray[CborNode]): CborNode =
  CborNode(kind: cborArray, seq: @x)

func toCbor*(pairs: openArray[(CborNode, CborNode)]): CborNode =
  CborNode(kind: cborMap, map: pairs.toOrderedTable)

func toCbor*(tag: uint64; val: CborNode): CborNode =
  result = toCbor(val)
  result.tag = some(tag)

func toCbor*(x: bool): CborNode =
  case x
  of false:
    CborNode(kind: cborSimple, simple: 20)
  of true:
    CborNode(kind: cborSimple, simple: 21)

func toCbor*(x: SomeFloat): CborNode =
  CborNode(kind: cborFloat, float: x.float64)

func toCbor*(x: pointer): CborNode =
  ## A hack to produce a CBOR null item.
  assert(x.isNil)
  CborNode(kind: cborSimple, simple: 22)

func initCborBytes*[T: char|byte](buf: openArray[T]): CborNode =
  ## Create a CBOR byte string from `buf`.
  result = CborNode(kind: cborBytes, bytes: newSeq[byte](buf.len))
  for i in 0..<buf.len:
    result.bytes[i] = (byte)buf[i]

func initCborBytes*(len: int): CborNode =
  ## Create a CBOR byte string of ``len`` bytes.
  CborNode(kind: cborBytes, bytes: newSeq[byte](len))

func initCborText*(s: string): CborNode =
  ## Create a CBOR text string from ``s``.
  ## CBOR text must be unicode.
  CborNode(kind: cborText, text: s)

func initCborArray*(): CborNode =
  ## Create an empty CBOR array.
  CborNode(kind: cborArray, seq: newSeq[CborNode]())

func initCborArray*(len: Natural): CborNode =
  ## Initialize a CBOR arrary.
  CborNode(kind: cborArray, seq: newSeq[CborNode](len))

func initCborMap*(initialSize = tables.defaultInitialSize): CborNode =
  ## Initialize a CBOR map.
  CborNode(kind: cborMap,
      map: initOrderedTable[CborNode, CborNode](initialSize))

func initCbor*(items: varargs[CborNode, toCbor]): CborNode =
  ## Initialize a CBOR arrary.
  CborNode(kind: cborArray, seq: @items)

template initCborOther*(x: untyped): CborNode =
  ## Initialize a ``CborNode`` from a type where ``toCbor`` is not implemented.
  ## This encodes ``x`` to binary using ``writeCbor``, so
  ## ``$(initCborOther(x))`` will incur an encode and decode roundtrip.
  let s = newStringStream()
  s.writeCbor(x)
  CborNode(kind: cborRaw, raw: s.data)

