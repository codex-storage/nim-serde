import std/macros

import ./types

export types

{.push raises: [].}

template serialize*(key = "", ignore = false, mode = SerdeMode.OptOut) {.pragma.}
template deserialize*(key = "", ignore = false, mode = SerdeMode.OptOut) {.pragma.}

proc isDefault[T](paramValue: T): bool {.compileTime.} =
  when T is SerdeMode:
    return paramValue == SerdeMode.OptOut
  else:
    return paramValue == T.default

template expectMissingPragmaParam*(value, pragma, name, msg) =
  static:
    when value.hasCustomPragma(pragma):
      const params = value.getCustomPragmaVal(pragma)
      for paramName, paramValue in params.fieldPairs:
        if paramName == name and not paramValue.isDefault:
          raiseAssert(msg)

template getSerdeFieldOptions*(pragma, fieldName, fieldValue): SerdeFieldOptions =
  var opts = SerdeFieldOptions(key: fieldName, ignore: false)
  when fieldValue.hasCustomPragma(pragma):
    fieldValue.expectMissingPragmaParam(
      pragma,
      "mode",
      "Cannot set " & astToStr(pragma) & " 'mode' on '" & fieldName &
        "' field defintion.",
    )
    let (key, ignore, _) = fieldValue.getCustomPragmaVal(pragma)
    opts.ignore = ignore
    if key != "":
      opts.key = key
  opts

template getSerdeMode*(T, pragma): SerdeMode =
  when T.hasCustomPragma(pragma):
    T.expectMissingPragmaParam(
      pragma,
      "key",
      "Cannot set " & astToStr(pragma) & " 'key' on '" & $T & "' type definition.",
    )
    T.expectMissingPragmaParam(
      pragma,
      "ignore",
      "Cannot set " & astToStr(pragma) & " 'ignore' on '" & $T & "' type definition.",
    )
    let (_, _, mode) = T.getCustomPragmaVal(pragma)
    mode
  else:
    # Default mode -- when the type is NOT annotated with a
    # serialize/deserialize pragma.
    #
    # NOTE This may be different in the logic branch above, when the type is
    # annotated with serialize/deserialize but doesn't specify a mode. The
    # default in that case will fallback to the default mode specified in the
    # pragma signature (currently OptOut for both serialize and deserialize)
    #
    # Examples:
    # 1. type MyObj = object
    #    Type is not annotated, mode defaults to OptOut (as specified on the
    #    pragma signatures) for both serialization and deserializtion
    #
    # 2. type MyObj {.serialize, deserialize.} = object
    #    Type is annotated, mode defaults to OptIn for serialization and OptOut
    #    for deserialization
    when astToStr(pragma) == "serialize":
      SerdeMode.OptIn
    elif astToStr(pragma) == "deserialize":
      SerdeMode.OptOut
