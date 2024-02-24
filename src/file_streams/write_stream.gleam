//// Use Erlang file write streams from Gleam.

import file_streams/file_error.{type FileError}
import file_streams/internal/raw_write_result.{type RawWriteResult}

/// A stream that binary data can be written to.
///
pub type WriteStream

type Mode {
  Binary
  Write
  DelayedWrite
  Raw
}

/// Creates a new write stream that writes binary data to a file. Once the
/// stream has been used it should be closed with `close`.
///
pub fn open(filename: String) -> Result(WriteStream, FileError) {
  file_open(filename, [Write, Binary, DelayedWrite, Raw])
}

@external(erlang, "file", "open")
fn file_open(
  filename: String,
  modes: List(Mode),
) -> Result(WriteStream, FileError)

/// Closes a write stream.
/// 
/// Because write streams are opened with delayed writes enabled to improve
/// performance, closing a stream can return an error related to flushing
/// recently written data to disk.
///
pub fn close(stream: WriteStream) -> Result(Nil, FileError) {
  case file_close(stream) {
    raw_write_result.Ok -> Ok(Nil)
    raw_write_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "close")
fn file_close(stream: WriteStream) -> RawWriteResult

/// Syncs a write stream which ensures that any write buffers kept by the
/// operating system (not by the Erlang runtime system) are written to disk.
/// 
/// Because write streams are opened with delayed writes enabled to improve
/// performance, syncing can return an error related to flushing recently
/// written data to disk.
///
pub fn sync(stream: WriteStream) -> Result(Nil, FileError) {
  case file_sync(stream) {
    raw_write_result.Ok -> Ok(Nil)
    raw_write_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "sync")
fn file_sync(stream: WriteStream) -> RawWriteResult

/// Writes bytes to a write stream.
///
pub fn write_bytes(
  stream: WriteStream,
  bytes: BitArray,
) -> Result(Nil, FileError) {
  case file_write(stream, bytes) {
    raw_write_result.Ok -> Ok(Nil)
    raw_write_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "write")
fn file_write(stream: WriteStream, bytes: BitArray) -> RawWriteResult
