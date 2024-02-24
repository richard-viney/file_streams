import file_streams/file_error.{type FileError}

pub type RawWriteResult {
  Ok
  Error(error: FileError)
}
