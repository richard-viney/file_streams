import file_streams/file_error.{type FileError}

pub type RawReadResult(a) {
  Ok(a)
  Eof
  Error(error: FileError)
}
