switch("path", "..")
when (NimMajor, NimMinor) >= (1, 4):
  switch("hint", "XCannotRaiseY:off")
when (NimMajor, NimMinor, NimPatch) >= (1, 6, 11):
  switch("warning", "BareExcept:off")