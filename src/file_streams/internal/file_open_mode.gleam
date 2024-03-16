import file_streams/file_encoding.{type FileEncoding}

pub type FileOpenMode {
  Binary
  DelayedWrite
  Raw
  Read
  ReadAhead
  Write
  Encoding(encoding: FileEncoding)
}
