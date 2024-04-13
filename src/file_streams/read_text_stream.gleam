//// Use Erlang text file read streams in Gleam.

import file_streams/file_encoding
import file_streams/file_error.{type FileError}
import file_streams/internal/file_open_mode.{type FileOpenMode}
import file_streams/internal/raw_read_result.{type RawReadResult}
import file_streams/internal/raw_result.{type RawResult}
import file_streams/read_stream_error.{type ReadStreamError}
import gleam/bit_array
import gleam/result

/// A stream that UTF-8 text can be read from.
///
pub type ReadTextStream

/// Opens a new stream that reads UTF-8 text data from a file. Once the stream
/// is no longer needed it should be closed with `close()`.
///
pub fn open(filename: String) -> Result(ReadTextStream, FileError) {
  file_open(filename, [
    file_open_mode.Binary,
    file_open_mode.Read,
    file_open_mode.ReadAhead,
    file_open_mode.Encoding(file_encoding.Unicode),
  ])
}

@external(erlang, "file", "open")
fn file_open(
  filename: String,
  modes: List(FileOpenMode),
) -> Result(ReadTextStream, FileError)

/// Closes a text stream.
///
pub fn close(stream: ReadTextStream) -> Result(Nil, ReadStreamError) {
  case file_close(stream) {
    raw_result.Ok -> Ok(Nil)
    raw_result.Error(e) -> Error(read_stream_error.OtherFileError(e))
  }
}

@external(erlang, "file", "close")
fn file_close(stream: ReadTextStream) -> RawResult

/// Reads the next line of UTF-8 text from a stream. The returned string value
/// will include the newline `\n` character. If the stream contains a Windows
/// newline `\r\n` then only the `\n` will be returned.
///
pub fn read_line(stream: ReadTextStream) -> Result(String, ReadStreamError) {
  case io_get_line(stream) {
    raw_read_result.Ok(data) ->
      data
      |> bit_array.to_string
      |> result.replace_error(read_stream_error.OtherFileError(
        file_error.InvalidUnicode,
      ))

    raw_read_result.Eof -> Error(read_stream_error.EndOfStream)
    raw_read_result.Error(e) -> Error(read_stream_error.OtherFileError(e))
  }
}

@external(erlang, "file_streams_erl", "io_get_line")
fn io_get_line(stream: ReadTextStream) -> RawReadResult(BitArray)

/// Reads the next `count` UTF-8 characters from a text stream. The returned
/// number of characters may be fewer than the number that was requested if the
/// end of the stream was reached.
///
pub fn read_chars(
  stream: ReadTextStream,
  count: Int,
) -> Result(String, ReadStreamError) {
  case io_get_chars(stream, count) {
    raw_read_result.Ok(data) ->
      data
      |> bit_array.to_string
      |> result.replace_error(read_stream_error.OtherFileError(
        file_error.InvalidUnicode,
      ))

    raw_read_result.Eof -> Error(read_stream_error.EndOfStream)
    raw_read_result.Error(e) -> Error(read_stream_error.OtherFileError(e))
  }
}

@external(erlang, "file_streams_erl", "io_get_chars")
fn io_get_chars(stream: ReadTextStream, count: Int) -> RawReadResult(BitArray)
