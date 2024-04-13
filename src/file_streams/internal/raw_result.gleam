import file_streams/file_error.{type FileError}

pub type RawResult {
  Ok
  Error(error: FileError)
}
