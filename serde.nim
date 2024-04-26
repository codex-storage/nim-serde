import pkg/chronicles except toJson
import ./serde/json

logScope:
  topics = "serde"

export json
