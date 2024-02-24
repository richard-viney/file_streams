import file_streams/file_error.{type FileError}

pub type RawReadResult {
  Ok(BitArray)
  Eof
  Error(error: FileError)
}
