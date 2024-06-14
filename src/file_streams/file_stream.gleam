//// Use Erlang file streams in Gleam.

import file_streams/file_stream_error.{type FileStreamError}
import file_streams/internal/raw_read_result.{type RawReadResult}
import file_streams/internal/raw_result.{type RawResult}
import file_streams/text_encoding.{type TextEncoding, Latin1}
import gleam/bit_array
import gleam/bool
import gleam/list
import gleam/result

/// The modes that can be specified when opening a file stream with
/// [`file_stream.open()`](./file_stream.html#open).
///
pub type FileOpenMode {
  /// The file is opened for writing. It is created if it does not exist. Every
  /// write operation to a file opened with `Append` takes place at the end of
  /// the file.
  Append

  /// Causes read operations on the file stream to return binaries rather than
  /// lists.
  ///
  /// This mode is always set by [`file_stream.open()`](./file_stream.html#open)
  /// and does not need to be specified manually.
  Binary

  /// Data in subsequent `file_stream.write_*` calls are buffered until at least
  /// `size` bytes are buffered, or until the oldest buffered data is `delay`
  /// milliseconds old. Then all buffered data is written in one operating
  /// system call. The buffered data is also flushed before some other file
  /// operations that are not `file_stream.write_*` calls.
  ///
  /// The purpose of this option is to increase performance by reducing the
  /// number of operating system calls. Thus, `file_stream.write_*` calls must
  /// be for sizes significantly less than `size`, and should not interspersed
  /// by too many other file operations.
  ///
  /// When this option is used, the result of `file_stream.write_*` calls can
  /// prematurely be reported as successful, and if a write error occurs, the
  /// error is reported as the result of the next file operation, which is not
  /// executed.
  ///
  /// For example, when `DelayedWrite` is used, after a number of
  /// `file_stream.write_*` calls,
  /// [`file_stream.close()`](./file_stream.html#close) can return
  /// `Error(FileStreamError(Enospc)))` as there is not enough space on the
  /// device for previously written data.
  /// [`file_stream.close()`](./file_stream.html#close) must be called again, as
  /// the file is still open.
  DelayedWrite(size: Int, delay: Int)

  /// Makes the file stream perform automatic translation of text to and from
  /// the specified text encoding when using the
  /// [`file_stream.read_line()`](./file_stream.html#read_line),
  /// [`file_stream.read_chars()`](./file_stream.html#read_chars), and
  /// [`file_stream.write_chars()`](./file_stream.html#write_chars) functions.
  ///
  /// If characters are written that can't be converted to the specified
  /// encoding then an error occurs and the file is closed.
  ///
  /// This option is not allowed when `Raw` is specified.
  Encoding(encoding: TextEncoding)

  /// The file is opened for writing. It is created if it does not exist. If the
  /// file exists, `Error(FileStreamError(Eexist))` is returned by
  /// [`file_stream.open()`](./file_stream.html#open).
  ///
  /// This option does not guarantee exclusiveness on file systems not
  /// supporting `O_EXCL` properly, such as NFS. Do not depend on this option
  /// unless you know that the file system supports it (in general, local file
  /// systems are safe).
  Exclusive

  /// Allows much faster access to a file, as no Erlang process is needed to
  /// handle the file. However, a file opened in this way has the following
  /// limitations:
  ///
  /// - Only the Erlang process that opened the file can use it.
  /// - The `Encoding` option can't be used and text-based reading and writing
  ///   is always done in UTF-8. This is because other text encodings depend on
  ///   the `io` module, which requires an Erlang process to talk to.
  /// - The [`file_stream.read_chars()`](./file_stream.html#read_chars) function
  ///   can't be used and will return `Error(Enotsup)`.
  /// - A remote Erlang file server cannot be used. The computer on which the
  ///   Erlang node is running must have access to the file system (directly or
  ///   through NFS).
  Raw

  /// The file, which must exist, is opened for reading.
  Read

  /// Activates read data buffering. If `file_stream.read_*` calls are for
  /// significantly less than `size` bytes, read operations to the operating
  /// system are still performed for blocks of `size` bytes. The extra data is
  /// buffered and returned in subsequent `file_stream.read_*` calls, giving a
  /// performance gain as the number of operating system calls is reduced.
  ///
  /// If `file_stream.read_*` calls are for sizes not significantly less than
  /// `size` bytes, or are greater than `size` bytes, no performance gain can be
  /// expected.
  ReadAhead(size: Int)

  /// The file is opened for writing. It is created if it does not exist. If the
  /// file exists and `Write` is not combined with `Read`, the file is
  /// truncated.
  Write
}

// ------------------------ Builder API for File Open Modes -------------------------------

type IoDevice

// Phantom types for FileStream

pub type Reader

pub type Writer

pub type Raw

pub type Latin1

pub type Unicode

pub type Utf16

pub type Utf32

pub opaque type FileStreamBuilder(is_read, is_write, is_raw, encoding) {
  FileStreamBuilder(modes: List(FileOpenMode))
}

/// Creates a new file stream builder with none of the open mode
/// options set
pub fn new_builder() -> FileStreamBuilder(Nil, Nil, Nil, Nil) {
  FileStreamBuilder([])
}

/// The file is opened for writing. It is created if it does not exist. If the
/// file exists and `Write` is not combined with `Read`, the file is
/// truncated.
pub fn write(
  file_stream_builder: FileStreamBuilder(a, Nil, b, c),
) -> FileStreamBuilder(a, Writer, b, c) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([Write, ..modes])
}

/// The file is opened for writing. It is created if it does not exist. Every
/// write operation to a file opened with `Append` takes place at the end of
/// the file.
pub fn append(
  file_stream_builder: FileStreamBuilder(a, Nil, b, c),
) -> FileStreamBuilder(a, Writer, b, c) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([Append, ..modes])
}

/// Adds the exclusive option to the filestream
pub fn exclusive(
  file_stream_builder: FileStreamBuilder(a, Nil, b, c),
) -> FileStreamBuilder(a, Writer, b, c) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([Append, ..modes])
}

/// The file, which must exist, is opened for reading.
pub fn read(
  file_stream_builder: FileStreamBuilder(Nil, a, b, c),
) -> FileStreamBuilder(Reader, a, b, c) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([Read, ..modes])
}

/// Activates read data buffering. If `file_stream.read_*` calls are for
/// significantly less than `size` bytes, read operations to the operating
/// system are still performed for blocks of `size` bytes. The extra data is
/// buffered and returned in subsequent `file_stream.read_*` calls, giving a
/// performance gain as the number of operating system calls is reduced.
///
/// If `file_stream.read_*` calls are for sizes not significantly less than
/// `size` bytes, or are greater than `size` bytes, no performance gain can be
/// expected.
pub fn read_ahead(
  file_stream_builder: FileStreamBuilder(Reader, a, b, c),
  size: Int,
) -> FileStreamBuilder(Reader, a, b, c) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([ReadAhead(size), ..modes])
}

/// Data in subsequent `file_stream.write_*` calls are buffered until at least
/// `size` bytes are buffered, or until the oldest buffered data is `delay`
/// milliseconds old. Then all buffered data is written in one operating
/// system call. The buffered data is also flushed before some other file
/// operations that are not `file_stream.write_*` calls.
///
/// The purpose of this option is to increase performance by reducing the
/// number of operating system calls. Thus, `file_stream.write_*` calls must
/// be for sizes significantly less than `size`, and should not interspersed
/// by too many other file operations.
///
/// When this option is used, the result of `file_stream.write_*` calls can
/// prematurely be reported as successful, and if a write error occurs, the
/// error is reported as the result of the next file operation, which is not
/// executed.
///
/// For example, when `DelayedWrite` is used, after a number of
/// `file_stream.write_*` calls,
/// [`file_stream.close()`](./file_stream.html#close) can return
/// `Error(FileStreamError(Enospc)))` as there is not enough space on the
/// device for previously written data.
/// [`file_stream.close()`](./file_stream.html#close) must be called again, as
/// the file is still open.
pub fn delayed_write(
  file_stream_builder: FileStreamBuilder(a, Nil, b, c),
  size: Int,
  delay: Int,
) -> FileStreamBuilder(a, Writer, b, c) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([DelayedWrite(size, delay), ..modes])
}

/// Allows much faster access to a file, as no Erlang process is needed to
/// handle the file. However, a file opened in this way has the following
/// limitations:
///
/// - Only the Erlang process that opened the file can use it.
/// - The `Encoding` option can't be used and text-based reading and writing
///   is always done in UTF-8. This is because other text encodings depend on
///   the `io` module, which requires an Erlang process to talk to.
/// - The [`file_stream.read_chars()`](./file_stream.html#read_chars) function
///   can't be used and will return `Error(Enotsup)`.
/// - A remote Erlang file server cannot be used. The computer on which the
///   Erlang node is running must have access to the file system (directly or
///   through NFS).
pub fn raw(
  file_stream_builder: FileStreamBuilder(a, b, Nil, c),
) -> FileStreamBuilder(a, b, Raw, Latin1) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([Raw, ..modes])
}

pub fn latin1(
  file_stream_builder: FileStreamBuilder(a, b, c, Nil),
) -> FileStreamBuilder(a, b, c, Latin1) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([Encoding(text_encoding.Latin1), ..modes])
}

pub fn unicode(
  file_stream_builder: FileStreamBuilder(a, b, c, Nil),
) -> FileStreamBuilder(a, b, c, Unicode) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([Encoding(text_encoding.Unicode), ..modes])
}

pub fn utf16_be(
  file_stream_builder: FileStreamBuilder(a, b, c, Nil),
) -> FileStreamBuilder(a, b, c, Utf16) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([Encoding(text_encoding.Utf16(text_encoding.Big)), ..modes])
}

pub fn utf16_le(
  file_stream_builder: FileStreamBuilder(a, b, c, Nil),
) -> FileStreamBuilder(a, b, c, Utf16) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([
    Encoding(text_encoding.Utf16(text_encoding.Little)),
    ..modes
  ])
}

pub fn utf32_be(
  file_stream_builder: FileStreamBuilder(a, b, c, Nil),
) -> FileStreamBuilder(a, b, c, Utf16) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([Encoding(text_encoding.Utf32(text_encoding.Big)), ..modes])
}

pub fn utf32_le(
  file_stream_builder: FileStreamBuilder(a, b, c, Nil),
) -> FileStreamBuilder(a, b, c, Utf16) {
  let FileStreamBuilder(modes) = file_stream_builder
  FileStreamBuilder([
    Encoding(text_encoding.Utf32(text_encoding.Little)),
    ..modes
  ])
}

pub fn build(
  file_stream_builder: FileStreamBuilder(a, b, c, d),
  filename: String,
) -> Result(FileStream(a, b, c, d), FileStreamError) {
  let FileStreamBuilder(modes) = file_stream_builder
  let is_raw = list.contains(modes, Raw)
  let encoding =
    list.find_map(modes, fn(m) {
      case m {
        Encoding(e) -> Ok(e)
        _ -> Error(Nil)
      }
    })
  use io_device <- result.try(erl_file_open(filename, modes))
  Ok(FileStream(io_device, is_raw, result.unwrap(encoding, Latin1)))
}

/// A file stream that data can be read from and/or written to depending on the
/// modes specified when it was opened.
///
pub opaque type FileStream(is_read, is_write, is_raw, encoding) {
  FileStream(io_device: IoDevice, is_raw: Bool, text_encoding: TextEncoding)
}

@external(erlang, "file", "open")
fn erl_file_open(
  filename: String,
  mode: List(FileOpenMode),
) -> Result(IoDevice, FileStreamError)

/// Closes an open file stream.
///
pub fn close(stream: FileStream(a, b, c, d)) -> Result(Nil, FileStreamError) {
  case erl_file_close(stream.io_device) {
    raw_result.Ok -> Ok(Nil)
    raw_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "close")
fn erl_file_close(io_device: IoDevice) -> RawResult

/// A file stream location defined relative to the beginning of the file,
/// the end of the file, or the current position in the file stream. This type
/// is used with the [`position()`](#position) function.
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
  stream: FileStream(a, b, c, d),
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

/// Writes raw bytes to a file stream.
///
/// This function is supported when the file stream was opened in `Raw` mode or
/// it uses the default `Latin1` text encoding. If this is not the case then
/// use [`write_chars()`](#write_chars).
///
pub fn write_bytes(
  stream: FileStream(a, Writer, b, Latin1),
  bytes: BitArray,
) -> Result(Nil, FileStreamError) {
  use <- bool.guard(
    stream.text_encoding != Latin1,
    Error(file_stream_error.Enotsup),
  )

  case erl_file_write(stream.io_device, bytes) {
    raw_result.Ok -> Ok(Nil)
    raw_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "write")
fn erl_file_write(io_device: IoDevice, bytes: BitArray) -> RawResult

/// Writes characters to a file stream. This will convert the characters to the
/// text encoding specified when the file stream was opened.
///
/// For file streams opened in `Raw` mode, use write_bytes.
///
pub fn write_chars(
  stream: FileStream(a, Writer, Nil, c),
  chars: String,
) -> Result(Nil, FileStreamError) {
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
pub fn sync(stream: FileStream(a, b, c, d)) -> Result(Nil, FileStreamError) {
  case erl_file_sync(stream.io_device) {
    raw_result.Ok -> Ok(Nil)
    raw_result.Error(e) -> Error(e)
  }
}

@external(erlang, "file", "sync")
fn erl_file_sync(io_device: IoDevice) -> RawResult

/// Reads bytes from a file stream. The returned number of bytes may be fewer
/// than the number that was requested if the end of the file stream was
/// reached.
///
/// If the end of the file stream is encountered before any bytes can be read
/// then `Error(Eof)` is returned.
///
/// This function is supported when the file stream was opened in `Raw` mode or
/// it uses the default `Latin1` text encoding. If this is not the case then
/// use [`read_chars()`](#read_chars) or [`read_line()`](#read_line).
///
pub fn read_bytes(
  stream: FileStream(Reader, a, b, Latin1),
  byte_count: Int,
) -> Result(BitArray, FileStreamError) {
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

/// Reads the requested number of bytes from a file stream. If the requested
/// number of bytes can't be read prior to reaching the end of the file stream
/// then `Error(Eof)` is returned.
///
/// This function is supported when the file stream was opened in `Raw` mode or
/// it uses the default `Latin1` text encoding. If this is not the case then use
/// [`read_chars()`](#read_chars) or [`read_line()`](#read_line) should be used
/// instead.
///
pub fn read_bytes_exact(
  stream: FileStream(Reader, a, b, Latin1),
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

/// Reads all remaining bytes from a file stream. If no more data is available
/// in the file stream then this function will return an empty bit array. It
/// never returns `Error(Eof)`.
///
/// This function is supported when the file stream was opened in `Raw` mode or
/// it uses the default `Latin1` text encoding. If this is not the case then use
/// [`read_chars()`](#read_chars) or [`read_line()`](#read_line) should be used
/// instead.
///
pub fn read_remaining_bytes(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(BitArray, FileStreamError) {
  do_read_remaining_bytes(stream, [])
}

fn do_read_remaining_bytes(
  stream: FileStream(Reader, a, b, Latin1),
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

/// Reads the next line of text from a file stream. The returned string
/// will include the newline `\n` character. If the stream contains a Windows
/// newline `\r\n` then only the `\n` will be returned.
///
/// This function always reads UTF-8 for file streams opened in `Raw` mode.
/// Otherwise, it uses the text encoding specified when the file was opened.
///
pub fn read_line(
  stream: FileStream(Reader, a, b, c),
) -> Result(String, FileStreamError) {
  case stream.is_raw {
    True ->
      case erl_file_read_line(stream.io_device) {
        raw_read_result.Ok(data) ->
          data
          |> bit_array.to_string
          |> result.replace_error(file_stream_error.InvalidUnicode)

        raw_read_result.Eof -> Error(file_stream_error.Eof)
        raw_read_result.Error(e) -> Error(e)
      }

    False ->
      case erl_io_get_line(stream.io_device) {
        raw_read_result.Ok(data) -> Ok(data)
        raw_read_result.Eof -> Error(file_stream_error.Eof)
        raw_read_result.Error(e) -> Error(e)
      }
  }
}

@external(erlang, "erl_file_streams", "io_get_line")
fn erl_io_get_line(io_device: IoDevice) -> RawReadResult(String)

@external(erlang, "file", "read_line")
fn erl_file_read_line(io_device: IoDevice) -> RawReadResult(BitArray)

/// Reads the next `count` characters from a file stream. The returned number of
/// characters may be fewer than the number that was requested if the end of the
/// stream is reached.
///
/// This function is not supported for file streams opened in `Raw` mode. Use the
/// [`read_line()`](#read_line) function instead.
///
pub fn read_chars(
  stream: FileStream(a, b, Nil, c),
  count: Int,
) -> Result(String, FileStreamError) {
  case erl_io_get_chars(stream.io_device, count) {
    raw_read_result.Ok(data) -> Ok(data)
    raw_read_result.Eof -> Error(file_stream_error.Eof)
    raw_read_result.Error(e) -> Error(e)
  }
}

@external(erlang, "erl_file_streams", "io_get_chars")
fn erl_io_get_chars(io_device: IoDevice, count: Int) -> RawReadResult(String)

/// Reads an 8-bit signed integer from a file stream.
///
pub fn read_int8(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 1))

  let assert <<v:signed-size(8)>> = bits
  v
}

/// Reads an 8-bit unsigned integer from a file stream.
///
pub fn read_uint8(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 1))

  let assert <<v:unsigned-size(8)>> = bits
  v
}

/// Reads a little-endian 16-bit signed integer from a file stream.
///
pub fn read_int16_le(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:little-signed-size(16)>> = bits
  v
}

/// Reads a big-endian 16-bit signed integer from a file stream.
///
pub fn read_int16_be(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:big-signed-size(16)>> = bits
  v
}

/// Reads a little-endian 16-bit unsigned integer from a file stream.
///
pub fn read_uint16_le(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:little-unsigned-size(16)>> = bits
  v
}

/// Reads a big-endian 16-bit unsigned integer from a file stream.
///
pub fn read_uint16_be(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 2))

  let assert <<v:big-unsigned-size(16)>> = bits
  v
}

/// Reads a little-endian 32-bit signed integer from a file stream.
///
pub fn read_int32_le(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:little-signed-size(32)>> = bits
  v
}

/// Reads a big-endian 32-bit signed integer from a file stream.
///
pub fn read_int32_be(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:big-signed-size(32)>> = bits
  v
}

/// Reads a little-endian 32-bit unsigned integer from a file stream.
///
pub fn read_uint32_le(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:little-unsigned-size(32)>> = bits
  v
}

/// Reads a big-endian 32-bit unsigned integer from a file stream.
///
pub fn read_uint32_be(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:big-unsigned-size(32)>> = bits
  v
}

/// Reads a little-endian 64-bit signed integer from a file stream.
///
pub fn read_int64_le(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:little-signed-size(64)>> = bits
  v
}

/// Reads a big-endian 64-bit signed integer from a file stream.
///
pub fn read_int64_be(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:big-signed-size(64)>> = bits
  v
}

/// Reads a little-endian 64-bit unsigned integer from a file stream.
///
pub fn read_uint64_le(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:little-unsigned-size(64)>> = bits
  v
}

/// Reads a big-endian 64-bit unsigned integer from a file stream.
///
pub fn read_uint64_be(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Int, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:big-unsigned-size(64)>> = bits
  v
}

/// Reads a little-endian 32-bit float from a file stream.
///
pub fn read_float32_le(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Float, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:little-float-size(32)>> = bits
  v
}

/// Reads a big-endian 32-bit float from a file stream.
///
pub fn read_float32_be(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Float, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 4))

  let assert <<v:big-float-size(32)>> = bits
  v
}

/// Reads a little-endian 64-bit float from a file stream.
///
pub fn read_float64_le(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Float, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:little-float-size(64)>> = bits
  v
}

/// Reads a big-endian 64-bit float from a file stream.
///
pub fn read_float64_be(
  stream: FileStream(Reader, a, b, Latin1),
) -> Result(Float, FileStreamError) {
  use bits <- result.map(read_bytes_exact(stream, 8))

  let assert <<v:big-float-size(64)>> = bits
  v
}

/// Reads the specified type the requested number of times from a file stream,
/// e.g. two little-endian 32-bit integers, or four big-endian 64-bit floats,
/// and returns the values in a list.
///
/// ## Examples
///
/// ```gleam
/// read_list(stream, read_int32_le, 2)
/// |> Ok([1, 2])
///
/// read_list(stream, read_float64_be, 4)
/// |> Ok([1.0, 2.0])
/// ```
///
pub fn read_list(
  stream: FileStream(Reader, a, b, c),
  item_read_fn: fn(FileStream(Reader, a, b, c)) -> Result(d, FileStreamError),
  item_count: Int,
) -> Result(List(d), FileStreamError) {
  do_read_list(stream, item_read_fn, item_count, [])
  |> result.map(list.reverse)
}

fn do_read_list(
  stream: FileStream(Reader, a, b, c),
  item_read_fn: fn(FileStream(Reader, a, b, c)) -> Result(d, FileStreamError),
  item_count: Int,
  acc: List(d),
) -> Result(List(d), FileStreamError) {
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
