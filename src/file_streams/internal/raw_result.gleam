import file_streams/file_stream_error.{type FileStreamError}

pub type RawResult {
  Ok
  Error(error: FileStreamError)
}
