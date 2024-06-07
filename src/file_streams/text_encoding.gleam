//// The encodings available for reading and writing text with a file stream.

/// Text encoding for a file stream. The default encoding is `Latin1`.
///
/// Text read from a file stream using
/// [`file_stream.read_chars()`](./file_stream.html#read_chars) and
/// [`file_stream.read_line()`](./file_stream.html#read_line) will be
/// automatically converted from the specified encoding to a `String`.
/// Similarly, text written to a file stream using
/// [`file_stream.write_chars()`](./file_stream.html#write_chars) will be
/// converted to the specified encoding before being written to a file stream.
///
pub type TextEncoding {
  /// The Unicode UTF-8 text encoding.
  Unicode

  /// The ISO 8859-1 (Latin-1) text encoding. This is the default encoding.
  ///
  /// When using this encoding,
  /// [`file_stream.write_chars()`](./file_stream.html#write_chars) can only
  /// write Unicode codepoints up to `U+00FF`.
  Latin1

  /// The Unicode UTF-16 text encoding, with the specified byte ordering.
  Utf16(endianness: Endianness)

  /// The Unicode UTF-32 text encoding, with the specified byte ordering.
  Utf32(endianness: Endianness)
}

/// Endianness specifier used by the `Utf16` and `Utf32` text encodings.
///
pub type Endianness {
  /// Big endian. This is much less common than little endian.
  Big

  /// Little endian. This is much more common than big endian.
  Little
}
