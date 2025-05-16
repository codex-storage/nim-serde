import std/[tables]
  
type CborNodeKind* = enum
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
    tag: Option[uint64]
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