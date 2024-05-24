import file_streams/file_stream_error.{type FileStreamError}

pub type RawReadResult(a) {
  Ok(a)
  Eof
  Error(error: FileStreamError)
}
