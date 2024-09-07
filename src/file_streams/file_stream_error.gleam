import file_streams/text_encoding.{type TextEncoding}

/// The reasons why a file stream operation can fail. Most of these map to
/// underlying POSIX errors.
///
pub type FileStreamError {
  /// Permission denied.
  Eacces

  /// Resource temporarily unavailable.
  Eagain

  /// Bad file number
  Ebadf

  /// Bad message.
  Ebadmsg

  /// File busy.
  Ebusy

  /// Resource deadlock avoided.
  Edeadlk

  /// On most architectures, same as `Edeadlk`. On some architectures, it
  ///
  /// means "File locking deadlock error."
  Edeadlock

  /// Disk quota exceeded.
  Edquot

  /// File already exists.
  Eexist

  /// Bad address in system call argument.
  Efault

  /// File too large.
  Efbig

  /// Inappropriate file type or format. Usually caused by trying to set the
  ///
  /// "sticky bit" on a regular file (not a directory).
  Eftype

  /// Interrupted system call.
  Eintr

  /// Invalid argument.
  Einval

  /// I/O error.
  Eio

  /// Illegal operation on a directory.
  Eisdir

  /// Too many levels of symbolic links.
  Eloop

  /// Too many open files.
  Emfile

  /// Too many links.
  Emlink

  /// Multihop attempted.
  Emultihop

  /// Filename too long
  Enametoolong

  /// File table overflow
  Enfile

  /// No buffer space available.
  Enobufs

  /// No such device.
  Enodev

  /// No locks available.
  Enolck

  /// Link has been severed.
  Enolink

  /// No such file or directory.
  Enoent

  /// Not enough memory.
  Enomem

  /// No space left on device.
  Enospc

  /// No STREAM resources.
  Enosr

  /// Not a STREAM.
  Enostr

  /// Function not implemented.
  Enosys

  /// Block device required.
  Enotblk

  /// Not a directory.
  Enotdir

  /// Operation not supported.
  Enotsup

  /// No such device or address.
  Enxio

  /// Operation not supported on socket.
  Eopnotsupp

  /// Value too large to be stored in data type.
  Eoverflow

  /// Not owner.
  Eperm

  /// Broken pipe.
  Epipe

  /// Result too large.
  Erange

  /// Read-only file system.
  Erofs

  /// Invalid seek.
  Espipe

  /// No such process.
  Esrch

  /// Stale remote file handle.
  Estale

  /// Text file busy.
  Etxtbsy

  /// Cross-domain link.
  Exdev

  /// The end of the file stream was reached before the requested data could
  /// be read.
  Eof

  /// Text data was encountered that can't be converted from/to the relevant
  /// text encoding. E.g. trying to write Chinese characters to a file stream
  /// opened with the `Latin1` encoding.
  NoTranslation(from: TextEncoding, to: TextEncoding)

  /// Data was encountered that is not valid Unicode. E.g. invalid bytes in a
  /// UTF-8 text file.
  InvalidUnicode
}

/// Returns a human-readable description of a file stream error.
///
pub fn describe(error: FileStreamError) -> String {
  case error {
    Eacces -> "Permission denied"
    Eagain -> "Resource temporarily unavailable"
    Ebadf -> "Bad file number"
    Ebadmsg -> "Bad message"
    Ebusy -> "File busy"
    Edeadlk -> "Resource deadlock avoided"
    Edeadlock -> "File locking deadlock error"
    Edquot -> "Disk quota exceeded"
    Eexist -> "File already exists"
    Efault -> "Bad address in system call argument"
    Efbig -> "File too large"
    Eftype -> "Inappropriate file type or format"
    Eintr -> "Interrupted system call"
    Einval -> "Invalid argument"
    Eio -> "I/O error"
    Eisdir -> "Illegal operation on a directory"
    Eloop -> "Too many levels of symbolic links"
    Emfile -> "Too many open files"
    Emlink -> "Too many links"
    Emultihop -> "Multihop attempted"
    Enametoolong -> "Filename too long"
    Enfile -> "File table overflow"
    Enobufs -> "No buffer space available"
    Enodev -> "No such device"
    Enoent -> "No such file or directory"
    Enolck -> "No locks available"
    Enolink -> "Link has been severed"
    Enomem -> "Not enough memory"
    Enospc -> "No space left on device"
    Enosr -> "No stream resources"
    Enostr -> "Not a stream"
    Enosys -> "Function not implemented"
    Enotblk -> "Block device required"
    Enotdir -> "Not a directory"
    Enotsup -> "Operation not supported"
    Enxio -> "No such device or address"
    Eopnotsupp -> "Operation not supported on socket"
    Eoverflow -> "Value too large to be stored in data type"
    Eperm -> "Permission denied due to file ownership"
    Epipe -> "Broken pipe"
    Erange -> "Result too large"
    Erofs -> "Read-only file system"
    Espipe -> "Invalid seek"
    Esrch -> "No such process"
    Estale -> "Stale remote file handle"
    Etxtbsy -> "Text file busy"
    Exdev -> "Cross-domain link"
    Eof -> "End of file stream"
    NoTranslation(..) -> "Unable to convert encoding"
    InvalidUnicode -> "Invalid bytes for Unicode encoding"
  }
}
