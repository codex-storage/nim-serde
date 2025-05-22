# This file is a modified version of Emery Hemingway’s CBOR library for Nim,
# originally available at https://github.com/ehmry/cbor-nim and released under The Unlicense.

import std/[streams, options, tables, typetraits, math, endians, times]
import pkg/questionable
import pkg/questionable/results
import ../utils/errors
import ./types

{.push raises: [].}

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

proc writeInitial[T: SomeInteger](str: Stream; m: uint8; n: T): ?!void =
  ## Write the initial integer of a CBOR item.
  try:
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
      success()
  except IOError as e:
    return failure(e.msg)
  except OSError as o:
    return failure(o.msg)

proc writeCborArrayLen*(str: Stream; len: Natural): ?!void =
  ## Write a marker to the stream that initiates an array of ``len`` items.
  str.writeInitial(4, len)

proc writeCborIndefiniteArrayLen*(str: Stream): ?!void =
  ## Write a marker to the stream that initiates an array of indefinite length.
  ## Indefinite length arrays are composed of an indefinite amount of arrays
  ## of definite lengths.
  catch str.write(initialByte(4, 31))

proc writeCborMapLen*(str: Stream; len: Natural): ?!void =
  ## Write a marker to the stream that initiates an map of ``len`` pairs.
  str.writeInitial(5, len)

proc writeCborIndefiniteMapLen*(str: Stream): ?!void =
  ## Write a marker to the stream that initiates a map of indefinite length.
  ## Indefinite length maps are composed of an indefinite amount of maps
  ## of definite length.
  catch str.write(initialByte(5, 31))

proc writeCborBreak*(str: Stream): ?!void =
  ## Write a marker to the stream that ends an indefinite array or map.
  catch str.write(initialByte(7, 31))

proc writeCborTag*(str: Stream; tag: Natural): ?!void {.inline.} =
  ## Write a tag for the next CBOR item to a binary stream.
  str.writeInitial(6, tag)

proc writeCbor*(str: Stream; buf: pointer; len: int): ?!void =
  ## Write a raw buffer to a CBOR `Stream`.
  ?str.writeInitial(BytesMajor, len)
  if len > 0:
    return catch str.writeData(buf, len)

proc isSorted*(n: CborNode): ?!bool {.gcsafe.}

proc writeCbor*[T](str: Stream; v: T): ?!void =
  ## Write the CBOR binary representation of a `T` to a `Stream`.
  ## The behavior of this procedure can be extended or overriden
  ## by defining `proc writeCborHook(str: Stream; v: T)` for specific
  ## types `T`.
  try:
    when T is CborNode:
      if v.tag.isSome:
        ?str.writeCborTag(v.tag.get)
      case v.kind:
      of cborUnsigned:
        return str.writeCbor(v.uint)
      of cborNegative:
        return str.writeCbor(v.int)
      of cborBytes:
        ?str.writeInitial(cborBytes.uint8, v.bytes.len)
        for b in v.bytes.items:
          str.write(b)
      of cborText:
        ?str.writeInitial(cborText.uint8, v.text.len)
        str.write(v.text)
      of cborArray:
        ?str.writeInitial(4, v.seq.len)
        for e in v.seq:
          ?str.writeCbor(e)
      of cborMap:
        without isSortedRes =? v.isSorted, error:
          return failure(error)
        if not isSortedRes:
          return failure(newSerdeError("refusing to write unsorted map to stream"))
        ?str.writeInitial(5, v.map.len)
        for k, f in v.map.pairs:
          ?str.writeCbor(k)
          ?str.writeCbor(f)
      of cborTag:
        discard
      of cborSimple:
        if v.simple > 31'u or v.simple == 24:
          str.write(initialByte(cborSimple.uint8, 24))
          str.write(v.simple)
        else:
          str.write(initialByte(cborSimple.uint8, v.simple))
      of cborFloat:
        return str.writeCbor(v.float)
      of cborRaw:
        str.write(v.raw)
    elif compiles(writeCborHook(str, v)):
      ?writeCborHook(str, v)
    elif T is SomeUnsignedInt:
      ?str.writeInitial(0, v)
    elif T is SomeSignedInt:
      if v < 0:
        # Major type 1
        ?str.writeInitial(1, -1 - v)
      else:
        # Major type 0
        ?str.writeInitial(0, v)
    elif T is seq[byte]:
      ?str.writeInitial(BytesMajor, v.len)
      if v.len > 0:
        str.writeData(unsafeAddr v[0], v.len)
    elif T is openArray[char | uint8 | int8]:
      ?str.writeInitial(BytesMajor, v.len)
      if v.len > 0:
        str.writeData(unsafeAddr v[0], v.len)
    elif T is string:
      ?str.writeInitial(TextMajor, v.len)
      str.write(v)
    elif T is array | seq:
      ?str.writeInitial(4, v.len)
      for e in v.items:
        ?str.writeCbor(e)
    elif T is tuple:
      ?str.writeInitial(4, T.tupleLen)
      for f in v.fields: ?str.writeCbor(f)
    elif T is ptr | ref:
      if system.`==`(v, nil):
        # Major type 7
        str.write(Null)
      else: ?str.writeCbor(v[])
    elif T is object:
      var n: uint
      for _, _ in v.fieldPairs:
        inc n
      ?str.writeInitial(5, n)
      for k, f in v.fieldPairs:
        ?str.writeCbor(k)
        ?str.writeCbor(f)
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
        return success()
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
    success()
  except IOError as io:
    return failure(io.msg)
  except OSError as os:
    return failure(os.msg)

proc writeCborArray*(str: Stream; args: varargs[CborNode, toCbor]): ?!void =
  ## Encode to a CBOR array in binary form. This magic doesn't
  ## always work, some arguments may need to be explicitly
  ## converted with ``toCbor`` before passing.
  ?str.writeCborArrayLen(args.len)
  for x in args:
    ?str.writeCbor(x)
  success()

proc encode*[T](v: T): ?!string =
  ## Encode an arbitrary value to CBOR binary representation.
  ## A wrapper over ``writeCbor``.
  let s = newStringStream()
  let res = s.writeCbor(v)
  if res.isFailure:
    return failure(res.error)
  success(s.data)

proc toRaw*(n: CborNode): ?!CborNode =
  ## Reduce a CborNode to a string of bytes.
  if n.kind == cborRaw:
    return success(n)
  else:
    without res =? encode(n), error:
      return failure(error)
    return success(CborNode(kind: cborRaw, raw: res))

proc isSorted(n: CborNode): ?!bool =
  ## Check if the item is sorted correctly.
  var lastRaw = ""
  for key in n.map.keys:
    without res =? key.toRaw, error:
      return failure(error.msg)
    let thisRaw = res.raw
    if lastRaw != "":
      if cmp(lastRaw, thisRaw) > 0: return success(false)
    lastRaw = thisRaw
  success(true)

proc sort*(n: var CborNode): ?!void =
  ## Sort a CBOR map object.
  try:
    var tmp = initOrderedTable[CborNode, CborNode](n.map.len.nextPowerOfTwo)
    for key, val in n.map.mpairs:
      without res =? key.toRaw, error:
        return failure(error)
      tmp[res] = move(val)
    sort(tmp) do (x, y: tuple[k: CborNode; v: CborNode]) -> int:
      result = cmp(x.k.raw, y.k.raw)
    n.map = move tmp
    success()
  except Exception as e:
    return failure(e.msg)

proc writeCborHook*(str: Stream; dt: DateTime): ?!void =
  ## Write a `DateTime` using the tagged string representation
  ## defined in RCF7049 section 2.4.1.
  ?writeCborTag(str, 0)
  ?writeCbor(str, format(dt, timeFormat))
  success()

proc writeCborHook*(str: Stream; t: Time): ?!void =
  ## Write a `Time` using the tagged numerical representation
  ## defined in RCF7049 section 2.4.1.
  ?writeCborTag(str, 1)
  ?writeCbor(str, t.toUnix)
  success()

func toCbor*(x: CborNode): ?!CborNode = success(x)

func toCbor*(x: SomeInteger): ?!CborNode =
  if x > 0:
    success(CborNode(kind: cborUnsigned, uint: x.uint64))
  else:
    success(CborNode(kind: cborNegative, int: x.int64))

func toCbor*(x: openArray[byte]): ?!CborNode =
  success(CborNode(kind: cborBytes, bytes: @x))

func toCbor*(x: string): ?!CborNode =
  success(CborNode(kind: cborText, text: x))

func toCbor*(x: openArray[CborNode]): ?!CborNode =
  success(CborNode(kind: cborArray, seq: @x))

func toCbor*(pairs: openArray[(CborNode, CborNode)]): ?!CborNode =
  try:
    return success(CborNode(kind: cborMap, map: pairs.toOrderedTable))
  except Exception as e:
    return failure(e.msg)

func toCbor*(tag: uint64; val: CborNode): ?!CborNode =
  without res =? toCbor(val), error:
    return failure(error.msg)
  var cnode = res
  cnode.tag = some(tag)
  return success(cnode)

func toCbor*(x: bool): ?!CborNode =
  case x
  of false:
    success(CborNode(kind: cborSimple, simple: 20))
  of true:
    success(CborNode(kind: cborSimple, simple: 21))

func toCbor*(x: SomeFloat): ?!CborNode =
  success(CborNode(kind: cborFloat, float: x.float64))

func toCbor*(x: pointer): ?!CborNode =
  ## A hack to produce a CBOR null item.
  assert(x.isNil)
  if not x.isNil:
    return failure("pointer is not nil")
  success(CborNode(kind: cborSimple, simple: 22))

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


