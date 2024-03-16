//// Use Erlang file write streams in Gleam.

import file_streams/file_error.{type FileError}
import file_streams/internal/file_open_mode.{type FileOpenMode}
import file_streams/internal/raw_write_result.{type RawWriteResult}

/// A stream that binary data can be written to.
///
pub type WriteStream

/// Creates a new write stream that writes binary data to a file. Once the
/// stream is no longer needed it should be closed with `close`.
///
pub fn open(filename: String) -> Result(WriteStream, FileError) {
  file_open(filename, [
    file_open_mode.Binary,
    file_open_mode.DelayedWrite,
    file_open_mode.Raw,
    file_open_mode.Write,
  ])
}

@external(erlang, "file", "open")
fn file_open(
  filename: String,
  modes: List(FileOpenMode),
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

/// Writes a UTF-8 string to a write stream.
///
pub fn write_string(
  stream: WriteStream,
  string: String,
) -> Result(Nil, FileError) {
  write_bytes(stream, <<string:utf8>>)
}

/// Writes a line to a write stream along with a trailing newline character.
///
pub fn write_line(stream: WriteStream, line: String) -> Result(Nil, FileError) {
  write_bytes(stream, <<line:utf8, 0x0A>>)
}
