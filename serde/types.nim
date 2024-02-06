import ./common

type
  UnexpectedKindError* = object of SerdeError
  SerdeMode* = enum
    OptOut, ## serialize:   all object fields will be serialized, except fields marked with 'ignore'
            ## deserialize: all json keys will be deserialized, no error if extra json field
    OptIn,  ## serialize:   only object fields marked with serialize will be serialzied
            ## deserialize: only fields marked with deserialize will be deserialized
    Strict  ## serialize:   all object fields will be serialized, regardless if the field is marked with 'ignore'
            ## deserialize: object fields and json fields must match exactly
