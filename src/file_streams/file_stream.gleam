//// Use Erlang file streams in Gleam.

import file_streams/file_open_mode.{type FileOpenMode}
import file_streams/file_stream_error.{type FileStreamError}
import file_streams/internal/raw_read_result.{type RawReadResult}
import file_streams/internal/raw_result.{type RawResult}
import file_streams/text_encoding
import gleam/bit_array
import gleam/bool
import gleam/list
import gleam/result
import gleam/string

type IoDevice

/// A file stream that data can be read from and/or written to depending on the
/// mode specified when it was opened.
///
pub opaque type FileStream {
  FileStream(io_device: IoDevice, is_binary: Bool)
}

/// Opens a new file stream that can read and/or write data from the specified
/// file. See [`FileOpenMode`](./file_open_mode.html#FileOpenMode) for all of
/// the available file modes.
///
/// For simple cases of opening a file stream use one of the
/// [`open_read()`](#open_read), [`open_read_text()`](#open_read_text),
/// [`open_write()`](#open_write), or [`open_write_text()`](#open_write_text)
/// helper functions.
/// 
/// Once the file stream is no longer needed it should be closed with
/// [`close()`](#close).
///
pub fn open(
  filename: String,
  mode: List(FileOpenMode),
) -> Result(FileStream, FileStreamError) {
  let is_binary = list.contains(mode, file_open_mode.Binary)

  let has_encoding =
    list.any(mode, fn(m) {
      case m {
        file_open_mode.Encoding(_) -> True
        _ -> False
      }
    })

  // Set UTF-8 as the default encoding for text streams
  let mode = case !is_binary && !has_encoding {
    True -> [file_open_mode.Encoding(text_encoding.Unicode), ..mode]
    False -> mode
  }

  // Raw mode is not compatible with text mode. This is because text mode
  // uses functions in the `io` module that don't work in raw mode.
  // See https://www.erlang.org/doc/apps/kernel/file.html#open/2.
  use <- bool.guard(
    !is_binary && list.contains(mode, file_open_mode.Raw),
    Error(file_stream_error.Enotsup),
  )

  use io_device <- result.try(erl_file_open(filename, mode))

  Ok(FileStream(io_device, is_binary))
}

@external(erlang, "file", "open")
fn erl_file_open(
  filename: String,
  mode: List(FileOpenMode),
) -> Result(IoDevice, FileStreamError)

/// Opens a new file stream for reading binary data from the specified file.
///
pub fn open_read(filename: String) -> Result(FileStream, FileStreamError) {
  open(filename, [
    file_open_mode.Read,
    file_open_mode.ReadAhead(64 * 1024),
    file_open_mode.Binary,
    file_open_mode.Raw,
  ])
}

/// Opens a new file stream for reading UTF-8 text from a file.
///
pub fn open_read_text(filename: String) -> Result(FileStream, FileStreamError) {
  open(filename, [
    file_open_mode.Read,
    file_open_mode.ReadAhead(size: 64 * 1024),
  ])
}

/// Opens a new file stream for writing binary data to the specified file.
///
pub fn open_write(filename: String) -> Result(FileStream, FileStreamError) {
  open(filename, [
    file_open_mode.Write,
    file_open_mode.DelayedWrite(size: 64 * 1024, delay: 2000),
    file_open_mode.Binary,
    file_open_mode.Raw,
  ])
}

/// Opens a new file stream for writing UTF-8 text to a file.
///
pub fn open_write_text(filename: String) -> Result(FileStream, FileStreamError) {
  open(filename, [
    file_open_mode.Write,
    file_open_mode.DelayedWrite(size: 64 * 1024, delay: 2000),
  ])
}

/// Closes a file stream that was opened with [`open()`](#open).
///
pub fn close(stream: FileStream) -> Result(Nil, FileStreamError) {
  case erl_file_close(stream.io_device) {
    raw_result.Ok -> Ok(Nil)
    raw_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "close")
fn erl_file_close(io_device: IoDevice) -> RawResult

/// A file stream location defined relative to the beginning of the file,
/// the end of the file, or the current position in the file stream. This is
/// used with the [`position()`](#position) function.
///
pub type FileStreamLocation {
  /// A location relative to the beginning of the file, i.e. an absolute offset
  /// in the file stream. The offset should not be negative.
  BeginningOfFile(offset: Int)

  /// A location relative to the current position in the file stream. The offset
  /// can be either positive or negative.
  CurrentLocation(offset: Int)

  /// A location relative to the end of the file stream. The offset should not
  /// be positive.
  EndOfFile(offset: Int)
}

/// Sets the position of a file stream to the given location, where the location
/// can be relative to the beginning of the file, the end of the file, or the
/// current position in the file. On success, returns the current position in
/// the file stream as an absolute offset in bytes.
///
pub fn position(
  stream: FileStream,
  location: FileStreamLocation,
) -> Result(Int, FileStreamError) {
  let location = case location {
    BeginningOfFile(offset) -> Bof(offset)
    CurrentLocation(offset) -> Cur(offset)
    EndOfFile(offset) -> Eof(offset)
  }

  erl_file_position(stream.io_device, location)
}

type ErlLocation {
  Bof(offset: Int)
  Cur(offset: Int)
  Eof(offset: Int)
}

@external(erlang, "file", "position")
fn erl_file_position(
  io_device: IoDevice,
  location: ErlLocation,
) -> Result(Int, FileStreamError)

/// Writes bytes to a binary file stream.
///
pub fn write_bytes(
  stream: FileStream,
  bytes: BitArray,
) -> Result(Nil, FileStreamError) {
  use <- bool.guard(!stream.is_binary, Error(file_stream_error.Enotsup))

  case erl_file_write(stream.io_device, bytes) {
    raw_result.Ok -> Ok(Nil)
    raw_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "write")
fn erl_file_write(io_device: IoDevice, bytes: BitArray) -> RawResult

/// Writes characters to a text file stream. This will convert the characters to
/// the text encoding in use for the file stream.
///
pub fn write_chars(
  stream: FileStream,
  chars: String,
) -> Result(Nil, FileStreamError) {
  use <- bool.guard(stream.is_binary, Error(file_stream_error.Enotsup))

  erl_io_put_chars(stream.io_device, chars)
}

@external(erlang, "erl_file_streams", "io_put_chars")
fn erl_io_put_chars(
  io_device: IoDevice,
  char_data: String,
) -> Result(Nil, FileStreamError)

/// Syncs a file stream that was opened for writing. This ensures that any write
/// buffers kept by the operating system (not by the Erlang runtime system) are
/// written to disk.
///
/// When a file stream is opened with delayed writes enabled to improve
/// performance, syncing can return an error related to flushing recently
/// written data to the underlying device.
///
pub fn sync(stream: FileStream) -> Result(Nil, FileStreamError) {
  case erl_file_sync(stream.io_device) {
    raw_result.Ok -> Ok(Nil)
    raw_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "sync")
fn erl_file_sync(io_device: IoDevice) -> RawResult

/// Reads bytes from a binary file stream. The returned number of bytes may be
/// fewer than the number that was requested if the end of the file stream was
/// reached.
///
/// If the end of the file stream is encountered before any bytes can be read
/// then `Error(Eof)` is returned.
///
pub fn read_bytes(
  stream: FileStream,
  byte_count: Int,
) -> Result(BitArray, FileStreamError) {
  use <- bool.guard(!stream.is_binary, Error(file_stream_error.Enotsup))

  case erl_file_read(stream.io_device, byte_count) {
    raw_read_result.Ok(bytes) -> Ok(bytes)
    raw_read_result.Eof -> Error(file_stream_error.Eof)
    raw_read_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "read")
fn erl_file_read(
  io_device: IoDevice,
  byte_count: Int,
) -> RawReadResult(BitArray)

/// Reads the requested number of bytes from a binary file stream. If the
/// requested number of bytes can't be read prior to reaching the end of the
/// file stream then `Error(Eof)` is returned.
///
pub fn read_bytes_exact(
  stream: FileStream,
  byte_count: Int,
) -> Result(BitArray, FileStreamError) {
  case read_bytes(stream, byte_count) {
    Ok(bytes) ->
      case bit_array.byte_size(bytes) == byte_count {
        True -> Ok(bytes)
        False -> Error(file_stream_error.Eof)
      }

    error -> error
  }
}

/// Reads all remaining bytes from a binary file stream.
///
/// If no more data is available in the file stream then this function will
/// return an empty bit array. It never returns `Error(Eof)`.
///
pub fn read_remaining_bytes(
  stream: FileStream,
) -> Result(BitArray, FileStreamError) {
  do_read_remaining_bytes(stream, [])
}

fn do_read_remaining_bytes(
  stream: FileStream,
  acc: List(BitArray),
) -> Result(BitArray, FileStreamError) {
  case read_bytes(stream, 64 * 1024) {
    Ok(bytes) -> do_read_remaining_bytes(stream, [bytes, ..acc])

    Error(file_stream_error.Eof) ->
      acc
      |> list.reverse
      |> bit_array.concat
      |> Ok

    Error(e) -> Error(e)
  }
}

/// Reads the next line of text from a text file stream. The returned string
/// will include the newline `\n` character. If the stream contains a Windows
/// newline `\r\n` then only the `\n` will be returned.
///
pub fn read_line(stream: FileStream) -> Result(String, FileStreamError) {
  use <- bool.guard(stream.is_binary, Error(file_stream_error.Enotsup))

  case erl_io_get_line(stream.io_device) {
    raw_read_result.Ok(data) -> codepoints_to_string(data)
    raw_read_result.Eof -> Error(file_stream_error.Eof)
    raw_read_result.Error(e) -> Error(e)
  }
}

@external(erlang, "erl_file_streams", "io_get_line")
fn erl_io_get_line(io_device: IoDevice) -> RawReadResult(List(Int))

/// Reads the next `count` characters from a text file stream. The returned
/// number of characters may be fewer than the number that was requested if the
/// end of the stream is reached.
///
pub fn read_chars(
  stream: FileStream,
  count: Int,
) -> Result(String, FileStreamError) {
  use <- bool.guard(stream.is_binary, Error(file_stream_error.Enotsup))

  case erl_io_get_chars(stream.io_device, count) {
    raw_read_result.Ok(data) -> codepoints_to_string(data)
    raw_read_result.Eof -> Error(file_stream_error.Eof)
    raw_read_result.Error(e) -> Error(e)
  }
}

@external(erlang, "erl_file_streams", "io_get_chars")
fn erl_io_get_chars(io_device: IoDevice, count: Int) -> RawReadResult(List(Int))

fn codepoints_to_string(
  codepoints: List(Int),
) -> Result(String, FileStreamError) {
  codepoints
  |> list.map(string.utf_codepoint)
  |> result.all
  |> result.map(string.from_utf_codepoints)
  |> result.replace_error(file_stream_error.InvalidTextData)
}

/// Reads an 8-bit signed integer from a binary file stream.
///
pub fn read_int8(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 1))

  let assert <<v:signed-size(8)>> = bits
  v
}

/// Reads an 8-bit unsigned integer from a binary file stream.
///
pub fn read_uint8(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 1))

  let assert <<v:unsigned-size(8)>> = bits
  v
}

/// Reads a little-endian 16-bit signed integer from a binary file stream.
///
pub fn read_int16_le(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:little-signed-size(16)>> = bits
  v
}

/// Reads a big-endian 16-bit signed integer from a binary file stream.
///
pub fn read_int16_be(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:big-signed-size(16)>> = bits
  v
}

/// Reads a little-endian 16-bit unsigned integer from a binary file stream.
///
pub fn read_uint16_le(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:little-unsigned-size(16)>> = bits
  v
}

/// Reads a big-endian 16-bit unsigned integer from a binary file stream.
///
pub fn read_uint16_be(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:big-unsigned-size(16)>> = bits
  v
}

/// Reads a little-endian 32-bit signed integer from a binary file stream.
///
pub fn read_int32_le(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:little-signed-size(32)>> = bits
  v
}

/// Reads a big-endian 32-bit signed integer from a binary file stream.
///
pub fn read_int32_be(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:big-signed-size(32)>> = bits
  v
}

/// Reads a little-endian 32-bit unsigned integer from a binary file stream.
///
pub fn read_uint32_le(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:little-unsigned-size(32)>> = bits
  v
}

/// Reads a big-endian 32-bit unsigned integer from a binary file stream.
///
pub fn read_uint32_be(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:big-unsigned-size(32)>> = bits
  v
}

/// Reads a little-endian 64-bit signed integer from a binary file stream.
///
pub fn read_int64_le(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:little-signed-size(64)>> = bits
  v
}

/// Reads a big-endian 64-bit signed integer from a binary file stream.
///
pub fn read_int64_be(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:big-signed-size(64)>> = bits
  v
}

/// Reads a little-endian 64-bit unsigned integer from a binary file stream.
///
pub fn read_uint64_le(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:little-unsigned-size(64)>> = bits
  v
}

/// Reads a big-endian 64-bit unsigned integer from a binary file stream.
///
pub fn read_uint64_be(stream: FileStream) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:big-unsigned-size(64)>> = bits
  v
}

/// Reads a little-endian 32-bit float from a binary file stream.
///
pub fn read_float32_le(stream: FileStream) -> Result(Float, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:little-float-size(32)>> = bits
  v
}

/// Reads a big-endian 32-bit float from a binary file stream.
///
pub fn read_float32_be(stream: FileStream) -> Result(Float, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:big-float-size(32)>> = bits
  v
}

/// Reads a little-endian 64-bit float from a binary file stream.
///
pub fn read_float64_le(stream: FileStream) -> Result(Float, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:little-float-size(64)>> = bits
  v
}

/// Reads a big-endian 64-bit float from a binary file stream.
///
pub fn read_float64_be(stream: FileStream) -> Result(Float, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:big-float-size(64)>> = bits
  v
}

/// Reads the specified type the requested number of times from a binary file
/// stream, e.g. two little-endian 32-bit integers, or four big-endian 64-bit
/// floats, and returns the values in a list.
///
/// ## Examples
///
/// ```gleam
/// read_list(stream, read_stream.read_int32_le, 2)
/// |> Ok([1, 2])
///
/// read_list(stream, read_stream.read_float64_be, 4)
/// |> Ok([1.0, 2.0])
/// ```
///
pub fn read_list(
  stream: FileStream,
  item_read_fn: fn(FileStream) -> Result(a, FileStreamError),
  item_count: Int,
) -> Result(List(a), FileStreamError) {
  do_read_list(stream, item_read_fn, item_count, [])
  |> result.map(list.reverse)
}

fn do_read_list(
  stream: FileStream,
  item_read_fn: fn(FileStream) -> Result(a, FileStreamError),
  item_count: Int,
  acc: List(a),
) -> Result(List(a), FileStreamError) {
  case item_count {
    0 -> Ok(acc)
    _ ->
      case item_read_fn(stream) {
        Ok(item) ->
          do_read_list(stream, item_read_fn, item_count - 1, [item, ..acc])
        Error(e) -> Error(e)
      }
  }
}
