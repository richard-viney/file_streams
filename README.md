# Gleam File Streams

This Gleam library provides access to Erlang's file streams for reading and
writing files. If you don't require streaming behaviour then consider using
[`simplifile`](https://hex.pm/packages/simplifile) instead.

[![Package Version](https://img.shields.io/hexpm/v/file_streams)](https://hex.pm/packages/file_streams)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/file_streams/)
![Erlang-compatible](https://img.shields.io/badge/target-erlang-a90432)

## Usage

Add this library to your project:

```sh
gleam add file_streams
```

API documentation can be found at <https://hexdocs.pm/file_streams/>.

### Binary File Streams & UTF-8

The following code writes data to a file using a file stream, then reads it
back in using a second file stream, first as raw bytes and then as lines of
UTF-8 text.

```gleam
import file_streams/file_stream
import file_streams/file_stream_error

pub fn main() {
  let filename = "test.txt"

  // Write file
  let assert Ok(stream) = file_stream.open_write(filename)
  let assert Ok(Nil) =
    file_stream.write_bytes(stream, <<"Hello, world!\n":utf8>>)
  let assert Ok(Nil) = file_stream.write_chars(stream, "12")
  let assert Ok(Nil) = file_stream.close(stream)

  // Read file
  let assert Ok(stream) = file_stream.open_read(filename)
  let assert Ok(<<"Hello, world!\n":utf8>>) = file_stream.read_bytes(stream, 14)
  let assert Ok([49, 50]) =
    file_stream.read_list(stream, file_stream.read_uint8, 2)
  let assert Error(file_stream_error.Eof) = file_stream.read_bytes(stream, 1)

  // Reset file position to the start and read line by line
  let assert Ok(0) =
    file_stream.position(stream, file_stream.BeginningOfFile(0))
  let assert Ok("Hello, world!\n") = file_stream.read_line(stream)
  let assert Ok("12") = file_stream.read_line(stream)
  let assert Error(file_stream_error.Eof) = file_stream.read_line(stream)
  let assert Ok(Nil) = file_stream.close(stream)
}
```

### Text File Streams

The following code reads a UTF-16 text file. The supported encodings are
`Latin1` (ISO 8859-1), `UTF-8`, `UTF-16`, and `UTF-32`.

```gleam
import file_streams/file_stream
import file_streams/file_stream_error
import file_streams/text_encoding

pub fn main() {
  let filename = "test.txt"
  let encoding = text_encoding.Utf16(text_encoding.Little)

  // Write UTF-16 text file
  let assert Ok(stream) = file_stream.open_write_text(filename, encoding)
  let assert Ok(Nil) = file_stream.write_chars(stream, "Hello, world!\n")
  let assert Ok(Nil) = file_stream.write_chars(stream, "Gleam is cool!\n")
  let assert Ok(Nil) = file_stream.close(stream)

  // Read UTF-16 text file
  let assert Ok(stream) = file_stream.open_read_text(filename, encoding)
  let assert Ok("Hello, world!\n") = file_stream.read_line(stream)
  let assert Ok("Gleam") = file_stream.read_chars(stream, 5)
  let assert Ok(" is cool!\n") = file_stream.read_line(stream)
  let assert Error(file_stream_error.Eof) = file_stream.read_line(stream)
  let assert Ok(Nil) = file_stream.close(stream)
}
```

## License

This library is published under the MIT license, a copy of which is included.
