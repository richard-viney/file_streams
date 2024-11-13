# Gleam File Streams

This Gleam library provides access to file streams for reading and writing
files. If you don't require streaming behavior then consider using
[`simplifile`](https://hex.pm/packages/simplifile) instead.

[![Package Version](https://img.shields.io/hexpm/v/file_streams)](https://hex.pm/packages/file_streams)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/file_streams/)
![Erlang Compatible](https://img.shields.io/badge/target-erlang-a90432)
![JavaScript Compatible](https://img.shields.io/badge/target-javascript-f3e155)
[![Semantic Release](https://img.shields.io/badge/semantic--release-conventionalcommits-e10079?logo=semantic-release)](https://github.com/semantic-release/semantic-release)

## Usage

Add this library to your project:

```sh
gleam add file_streams
```

The following code writes data to a file using a file stream, then reads it back
in using a second file stream, first as raw bytes and then as lines of UTF-8
text.

```gleam
import file_streams/file_stream
import file_streams/file_stream_error

pub fn main() {
  let filename = "test.txt"

  // Write file
  let assert Ok(stream) = file_stream.open_write(filename)
  let assert Ok(Nil) = file_stream.write_bytes(stream, <<"Hello!\n":utf8>>)
  let assert Ok(Nil) = file_stream.write_chars(stream, "12")
  let assert Ok(Nil) = file_stream.close(stream)

  // Read file
  let assert Ok(stream) = file_stream.open_read(filename)
  let assert Ok(<<"Hello!\n":utf8>>) = file_stream.read_bytes(stream, 7)
  let assert Ok([49, 50]) =
    file_stream.read_list(stream, file_stream.read_uint8, 2)
  let assert Error(file_stream_error.Eof) = file_stream.read_bytes(stream, 1)

  // Reset file position to the start and read line by line (not currently
  // supported on JavaScript)
  let assert Ok(0) =
    file_stream.position(stream, file_stream.BeginningOfFile(0))
  let assert Ok("Hello!\n") = file_stream.read_line(stream)
  let assert Ok("12") = file_stream.read_line(stream)
  let assert Error(file_stream_error.Eof) = file_stream.read_line(stream)
  let assert Ok(Nil) = file_stream.close(stream)
}
```

### Working with Text Encodings

> [!NOTE]
> Text encodings are not currently supported on the JavaScript target.

If a text encoding is specified when opening a file stream it allows for
reading and writing of characters and lines of text stored in that encoding.
To open a text file stream use the `file_stream.open_read_text()` and
`file_stream.open_write_text()` functions. The supported encodings are `Latin1`,
`Unicode` (UTF-8), `Utf16`, and `Utf32`. The default encoding is `Latin1`.

File streams opened with a text encoding aren't compatible with the `Raw` file
open mode that significantly improves IO performance on Erlang. Specifying both
`Raw` and `Encoding` when calling `file_stream.open()` returns `Error(Enotsup)`.

Although a text encoding can't be specified with `Raw` mode, the
`file_stream.read_line()` and `file_stream.write_chars()` functions can still be
used to work with UTF-8 data. This means that text encoded as UTF-8 can be
handled with high performance in `Raw` mode.

When a text encoding other than `Latin1` is specified, functions that read and
write raw bytes and other binary data aren't supported and will return
`Error(Enotsup)`.

The following code demonstrates working with a UTF-16 file stream.

```gleam
import file_streams/file_stream
import file_streams/file_stream_error
import file_streams/text_encoding

pub fn main() {
  let filename = "test.txt"
  let encoding = text_encoding.Utf16(text_encoding.Little)

  // Write UTF-16 text file
  let assert Ok(stream) = file_stream.open_write_text(filename, encoding)
  let assert Ok(Nil) = file_stream.write_chars(stream, "Hello!\n")
  let assert Ok(Nil) = file_stream.write_chars(stream, "Gleam is cool!\n")
  let assert Ok(Nil) = file_stream.close(stream)

  // Read UTF-16 text file
  let assert Ok(stream) = file_stream.open_read_text(filename, encoding)
  let assert Ok("Hello!\n") = file_stream.read_line(stream)
  let assert Ok("Gleam") = file_stream.read_chars(stream, 5)
  let assert Ok(" is cool!\n") = file_stream.read_line(stream)
  let assert Error(file_stream_error.Eof) = file_stream.read_line(stream)
  let assert Ok(Nil) = file_stream.close(stream)
}
```

### API Documentation

API documentation can be found at <https://hexdocs.pm/file_streams/>.

## License

This library is published under the MIT license, a copy of which is included.
