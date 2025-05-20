import ./types

{.push raises: [].}

proc mapErrTo*[E1: ref CatchableError, E2: SerdeError](
    e1: E1, _: type E2, msg: string = e1.msg
): ref E2 =
  return newException(E2, msg, e1)

proc newSerdeError*(msg: string): ref SerdeError =
  newException(SerdeError, msg)



