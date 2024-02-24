# Gleam File Streams

This Gleam library provides access to Erlang's binary file streams for reading
and writing files. If you don't require streaming behavior then consider using
[`simplifile`](https://hex.pm/packages/simplifile) instead.

This library only supports the Erlang target.

[![Package Version](https://img.shields.io/hexpm/v/file_streams)](https://hex.pm/packages/file_streams)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/file_streams/)

## Example

Add this library to your project:

```sh
gleam add file_streams
```

The following code writes a string to a file using a write stream and then reads
it back in using a read stream.

```gleam
import file_streams/read_stream
import file_streams/write_stream
import gleam/bit_array

// ...

let assert Ok(ws) = write_stream.open("test.txt")
let assert Ok(Nil) = write_stream.write_bytes(ws, <<"Hello, world!":utf8>>)
let assert Ok(Nil) = write_stream.write_bytes(ws, <<"12":utf8>>)
let assert Ok(Nil) = write_stream.close(ws)

let assert Ok(rs) = read_stream.open("test.txt")

let assert Ok(bytes) = read_stream.read_bytes(rs, 13)
let assert Ok("Hello, world!") = bit_array.to_string(bytes)
let assert Ok([49, 50]) = read_stream.read_list(rs, read_stream.read_uint8, 2)

let assert Error(read_stream.EndOfStream) = read_stream.read_bytes(rs, 1)

read_stream.close(rs)
```

Further documentation can be found at <https://hexdocs.pm/file_streams>.

## License

This library is published under the MIT license, a copy of which is included.
