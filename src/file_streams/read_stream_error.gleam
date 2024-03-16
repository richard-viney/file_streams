import file_streams/file_error.{type FileError}

/// Errors that can occur when using a read stream.
///
pub type ReadStreamError {
  /// The end of the stream was reached before the requested data could
  /// be read.
  EndOfStream

  /// A file error occurred while reading from the stream.
  OtherFileError(error: FileError)
}
