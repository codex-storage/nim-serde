import std/strutils

func flatten*(s: string): string =
  s.replace(" ").replace("\n")
