//// Use Erlang binary file read streams in Gleam.

import file_streams/file_error.{type FileError}
import file_streams/internal/file_open_mode.{type FileOpenMode}
import file_streams/internal/raw_read_result.{type RawReadResult}
import file_streams/internal/raw_result.{type RawResult}
import file_streams/read_stream_error.{type ReadStreamError}
import gleam/bit_array
import gleam/list
import gleam/result

/// A stream that data can be read from.
///
pub type ReadStream

/// Opens a new read stream that reads binary or text data from a file. Once the
/// stream is no longer needed it should be closed with `close()`.
///
pub fn open(filename: String) -> Result(ReadStream, FileError) {
  file_open(filename, [
    file_open_mode.Binary,
    file_open_mode.Raw,
    file_open_mode.Read,
    file_open_mode.ReadAhead,
  ])
}

@external(erlang, "file", "open")
fn file_open(
  filename: String,
  modes: List(FileOpenMode),
) -> Result(ReadStream, FileError)

/// Closes a read stream.
///
pub fn close(stream: ReadStream) -> Result(Nil, ReadStreamError) {
  case file_close(stream) {
    raw_result.Ok -> Ok(Nil)
    raw_result.Error(e) -> Error(read_stream_error.OtherFileError(e))
  }
}

@external(erlang, "file", "close")
fn file_close(stream: ReadStream) -> RawResult

/// Reads bytes from a read stream. The returned number of bytes may be fewer
/// than the number that was requested if the end of the stream was reached.
/// 
/// If the end of the stream is encountered before any bytes can be read then
/// `EndOfStream` is returned.
///
pub fn read_bytes(
  stream: ReadStream,
  byte_count: Int,
) -> Result(BitArray, ReadStreamError) {
  case file_read(stream, byte_count) {
    raw_read_result.Ok(bytes) -> Ok(bytes)
    raw_read_result.Eof -> Error(read_stream_error.EndOfStream)
    raw_read_result.Error(e) -> Error(read_stream_error.OtherFileError(e))
  }
}

/// Reads the requested number of bytes from a read stream. If the requested
/// number of bytes can't be read prior to reaching the end of the stream then
/// `EndOfStream` is returned.
///
pub fn read_bytes_exact(
  stream: ReadStream,
  byte_count: Int,
) -> Result(BitArray, ReadStreamError) {
  case read_bytes(stream, byte_count) {
    Ok(bytes) ->
      case bit_array.byte_size(bytes) == byte_count {
        True -> Ok(bytes)
        False -> Error(read_stream_error.EndOfStream)
      }

    error -> error
  }
}

/// Reads all remaining bytes from a read stream.
/// 
/// If no more data is available in the read stream then this function will
/// return an empty bit array. It never returns an `EndOfStream` error.
///
pub fn read_remaining_bytes(
  stream: ReadStream,
) -> Result(BitArray, ReadStreamError) {
  do_read_remaining_bytes(stream, [])
}

fn do_read_remaining_bytes(
  stream: ReadStream,
  acc: List(BitArray),
) -> Result(BitArray, ReadStreamError) {
  case read_bytes(stream, 64 * 1024) {
    Ok(bytes) -> do_read_remaining_bytes(stream, [bytes, ..acc])

    Error(read_stream_error.EndOfStream) ->
      acc
      |> list.reverse
      |> bit_array.concat
      |> Ok

    Error(e) -> Error(e)
  }
}

@external(erlang, "file", "read")
fn file_read(stream: ReadStream, byte_count: Int) -> RawReadResult(BitArray)

/// Reads an 8-bit signed integer from a read stream.
///
pub fn read_int8(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 1))

  let assert <<v:signed-size(8)>> = bits
  v
}

/// Reads an 8-bit unsigned integer from a read stream.
///
pub fn read_uint8(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 1))

  let assert <<v:unsigned-size(8)>> = bits
  v
}

/// Reads a little-endian 16-bit signed integer from a read stream.
///
pub fn read_int16_le(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:little-signed-size(16)>> = bits
  v
}

/// Reads a big-endian 16-bit signed integer from a read stream.
///
pub fn read_int16_be(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:big-signed-size(16)>> = bits
  v
}

/// Reads a little-endian 16-bit unsigned integer from a read stream.
///
pub fn read_uint16_le(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:little-unsigned-size(16)>> = bits
  v
}

/// Reads a big-endian 16-bit unsigned integer from a read stream.
///
pub fn read_uint16_be(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:big-unsigned-size(16)>> = bits
  v
}

/// Reads a little-endian 32-bit signed integer from a read stream.
///
pub fn read_int32_le(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:little-signed-size(32)>> = bits
  v
}

/// Reads a big-endian 32-bit signed integer from a read stream.
///
pub fn read_int32_be(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:big-signed-size(32)>> = bits
  v
}

/// Reads a little-endian 32-bit unsigned integer from a read stream.
///
pub fn read_uint32_le(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:little-unsigned-size(32)>> = bits
  v
}

/// Reads a big-endian 32-bit unsigned integer from a read stream.
///
pub fn read_uint32_be(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:big-unsigned-size(32)>> = bits
  v
}

/// Reads a little-endian 64-bit signed integer from a read stream.
///
pub fn read_int64_le(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:little-signed-size(64)>> = bits
  v
}

/// Reads a big-endian 64-bit signed integer from a read stream.
///
pub fn read_int64_be(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:big-signed-size(64)>> = bits
  v
}

/// Reads a little-endian 64-bit unsigned integer from a read stream.
///
pub fn read_uint64_le(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:little-unsigned-size(64)>> = bits
  v
}

/// Reads a big-endian 64-bit unsigned integer from a read stream.
///
pub fn read_uint64_be(stream: ReadStream) -> Result(Int, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:big-unsigned-size(64)>> = bits
  v
}

/// Reads a little-endian 32-bit float from a read stream.
///
pub fn read_float32_le(stream: ReadStream) -> Result(Float, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:little-float-size(32)>> = bits
  v
}

/// Reads a big-endian 32-bit float from a read stream.
///
pub fn read_float32_be(stream: ReadStream) -> Result(Float, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:big-float-size(32)>> = bits
  v
}

/// Reads a little-endian 64-bit float from a read stream.
///
pub fn read_float64_le(stream: ReadStream) -> Result(Float, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:little-float-size(64)>> = bits
  v
}

/// Reads a big-endian 64-bit float from a read stream.
///
pub fn read_float64_be(stream: ReadStream) -> Result(Float, ReadStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:big-float-size(64)>> = bits
  v
}

/// Reads the specified type the requested number of times, e.g. two
/// little-endian 32-bit integers, or four big-endian 64-bit floating point
/// values, and returns the values in a list.
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
  stream: ReadStream,
  item_read_fn: fn(ReadStream) -> Result(a, ReadStreamError),
  item_count: Int,
) -> Result(List(a), ReadStreamError) {
  do_read_list(stream, item_read_fn, item_count, [])
  |> result.map(list.reverse)
}

fn do_read_list(
  stream: ReadStream,
  item_read_fn: fn(ReadStream) -> Result(a, ReadStreamError),
  item_count: Int,
  acc: List(a),
) -> Result(List(a), ReadStreamError) {
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
