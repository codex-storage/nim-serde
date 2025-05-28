# This file is a modified version of Emery Hemingway’s CBOR library for Nim,
# originally available at https://github.com/ehmry/cbor-nim and released under The Unlicense.

import std/[streams, tables, options, hashes, times]

# This format is defined in RCF8949 section 3.4.1.
const dateTimeFormat* = initTimeFormat "yyyy-MM-dd'T'HH:mm:sszzz"

const
  PositiveMajor* = 0'u8
  NegativeMajor* = 1'u8
  BytesMajor* = 2'u8
  TextMajor* = 3'u8
  ArrayMajor* = 4'u8
  MapMajor* = 5'u8
  TagMajor* = 6'u8
  SimpleMajor* = 7'u8
  Null* = 0xf6'u8

type
  CborEventKind* {.pure.} = enum
    ## enumeration of events that may occur while parsing
    cborEof,
    cborPositive,
    cborNegative,
    cborBytes,
    cborText,
    cborArray,
    cborMap,
    cborTag,
    cborSimple,
    cborFloat,
    cborBreak

  CborParser* = object ## CBOR parser state.
    s*: Stream
    intVal*: uint64
    minor*: uint8
    kind*: CborEventKind

type
  CborNodeKind* = enum
    cborUnsigned = 0,
    cborNegative = 1,
    cborBytes = 2,
    cborText = 3,
    cborArray = 4,
    cborMap = 5,
    cborTag = 6,
    cborSimple = 7,
    cborFloat,
    cborRaw

  CborNode* = object
    ## An abstract representation of a CBOR item. Useful for diagnostics.
    tag*: Option[uint64]
    case kind*: CborNodeKind
    of cborUnsigned:
      uint*: BiggestUInt
    of cborNegative:
      int*: BiggestInt
    of cborBytes:
      bytes*: seq[byte]
    of cborText:
      text*: string
    of cborArray:
      seq*: seq[CborNode]
    of cborMap:
      map*: OrderedTable[CborNode, CborNode]
    of cborTag:
      discard
    of cborSimple:
      simple*: uint8
    of cborFloat:
      float*: float64
    of cborRaw:
      raw*: string

func `==`*(x, y: CborNode): bool

func hash*(x: CborNode): Hash

func `==`*(x, y: CborNode): bool =
  if x.kind == y.kind and x.tag == y.tag:
    case x.kind
    of cborUnsigned:
      x.uint == y.uint
    of cborNegative:
      x.int == y.int
    of cborBytes:
      x.bytes == y.bytes
    of cborText:
      x.text == y.text
    of cborArray:
      x.seq == y.seq
    of cborMap:
      x.map == y.map
    of cborTag:
      false
    of cborSimple:
      x.simple == y.simple
    of cborFloat:
      x.float == y.float
    of cborRaw:
      x.raw == y.raw
  else:
    false

func `==`*(x: CborNode; y: SomeInteger): bool =
  case x.kind
  of cborUnsigned:
    x.uint == y
  of cborNegative:
    x.int == y
  else:
    false

func `==`*(x: CborNode; y: string): bool =
  x.kind == cborText and x.text == y

func `==`*(x: CborNode; y: SomeFloat): bool =
  if x.kind == cborFloat: x.float == y

func hash(x: CborNode): Hash =
  var h = hash(get(x.tag, 0))
  h = h !& x.kind.int.hash
  case x.kind
  of cborUnsigned:
    h = h !& x.uint.hash
  of cborNegative:
    h = h !& x.int.hash
  of cborBytes:
    h = h !& x.bytes.hash
  of cborText:
    h = h !& x.text.hash
  of cborArray:
    for y in x.seq:
      h = h !& y.hash
  of cborMap:
    for key, val in x.map.pairs:
      h = h !& key.hash
      h = h !& val.hash
  of cborTag:
    discard
  of cborSimple:
    h = h !& x.simple.hash
  of cborFloat:
    h = h !& x.float.hash
  of cborRaw:
    assert(x.tag.isNone)
    h = x.raw.hash
  !$h

proc `[]`*(n, k: CborNode): CborNode = n.map[k]
  ## Retrieve a value from a CBOR map.

proc `[]=`*(n: var CborNode; k, v: sink CborNode) = n.map[k] = v
  ## Assign a pair in a CBOR map.

func len*(node: CborNode): int =
  ## Return the logical length of a ``CborNode``, that is the
  ## length of a byte or text string, or the number of
  ## elements in a array or map. Otherwise it returns -1.
  case node.kind
  of cborBytes: node.bytes.len
  of cborText: node.text.len
  of cborArray: node.seq.len
  of cborMap: node.map.len
  else: -1
