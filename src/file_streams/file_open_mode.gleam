import file_streams/text_encoding.{type TextEncoding}

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
  ///
  /// The text encoding of an open file stream can be changed with
  /// [`file_stream.set_encoding()`](./file_stream.html#set_encoding) function.
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
