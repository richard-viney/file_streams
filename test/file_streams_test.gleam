import file_streams/file_open_mode
import file_streams/file_stream
import file_streams/file_stream_error
@target(erlang)
import file_streams/text_encoding
import gleam/bit_array
import gleam/string
import gleeunit
import gleeunit/should
import simplifile

const tmp_file_name = "file_streams.test"

pub fn main() {
  gleeunit.main()
}

pub fn open_missing_file_test() {
  file_stream.open_read("missing_file.txt")
  |> should.equal(Error(file_stream_error.Enoent))
}

pub fn open_directory_test() {
  file_stream.open_read("src")
  |> should.equal(Error(file_stream_error.Eisdir))
}

pub fn read_ints_and_floats_test() {
  simplifile.write_bits(
    tmp_file_name,
    bit_array.concat([
      <<-100:int-size(8), 200:int-size(8)>>,
      // 16-bit integers
      <<
        -3000:little-int-size(16), -3000:big-int-size(16),
        10_000:little-int-size(16), 10_000:big-int-size(16),
      >>,
      // 32-bit integers
      <<
        -300_000:little-int-size(32), -300_000:big-int-size(32),
        1_000_000:little-int-size(32), 1_000_000:big-int-size(32),
      >>,
      // 64-bit integers
      <<
        9_007_199_254_740_991:little-int-size(64),
        9_007_199_254_740_991:big-int-size(64),
      >>,
      // 32-bit floats
      <<
        1.5:little-float-size(32), 1.5:big-float-size(32),
        2.5:little-float-size(64), 2.5:big-float-size(64),
      >>,
      // 64-bit floats
      <<
        1.0:little-float-size(64), 2.0:little-float-size(64),
        3.0:little-float-size(64),
      >>,
    ]),
  )
  |> should.equal(Ok(Nil))

  let assert Ok(stream) =
    file_stream.open(tmp_file_name, [file_open_mode.Read, file_open_mode.Raw])

  file_stream.read_int8(stream)
  |> should.equal(Ok(-100))

  file_stream.read_uint8(stream)
  |> should.equal(Ok(200))

  file_stream.read_int16_le(stream)
  |> should.equal(Ok(-3000))
  file_stream.read_int16_be(stream)
  |> should.equal(Ok(-3000))

  file_stream.read_uint16_le(stream)
  |> should.equal(Ok(10_000))
  file_stream.read_uint16_be(stream)
  |> should.equal(Ok(10_000))

  file_stream.read_int32_le(stream)
  |> should.equal(Ok(-300_000))
  file_stream.read_int32_be(stream)
  |> should.equal(Ok(-300_000))

  file_stream.read_uint32_le(stream)
  |> should.equal(Ok(1_000_000))
  file_stream.read_uint32_be(stream)
  |> should.equal(Ok(1_000_000))

  file_stream.read_uint64_le(stream)
  |> should.equal(Ok(9_007_199_254_740_991))
  file_stream.read_uint64_be(stream)
  |> should.equal(Ok(9_007_199_254_740_991))

  file_stream.read_float32_le(stream)
  |> should.equal(Ok(1.5))
  file_stream.read_float32_be(stream)
  |> should.equal(Ok(1.5))

  file_stream.read_float64_le(stream)
  |> should.equal(Ok(2.5))
  file_stream.read_float64_be(stream)
  |> should.equal(Ok(2.5))

  file_stream.read_list(stream, file_stream.read_float64_le, 2)
  |> should.equal(Ok([1.0, 2.0]))

  file_stream.position(stream, file_stream.BeginningOfFile(83))
  |> should.equal(Ok(83))

  file_stream.read_bytes_exact(stream, 0)
  |> should.equal(Ok(<<>>))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

pub fn read_bytes_exact_test() {
  simplifile.write(tmp_file_name, "Test")
  |> should.equal(Ok(Nil))

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)

  file_stream.read_bytes_exact(stream, 2)
  |> should.equal(Ok(<<"Te":utf8>>))

  file_stream.read_bytes_exact(stream, 3)
  |> should.equal(Error(file_stream_error.Eof))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

pub fn read_remaining_bytes_test() {
  simplifile.write(tmp_file_name, string.repeat("Test", 50_000))
  |> should.equal(Ok(Nil))

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)
  let assert Ok(_) = file_stream.read_bytes_exact(stream, 100_000)

  let assert Ok(remaining_bytes) = file_stream.read_remaining_bytes(stream)

  remaining_bytes
  |> bit_array.to_string
  |> should.equal(Ok(string.repeat("Test", 25_000)))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

pub fn position_test() {
  simplifile.write(tmp_file_name, "Test1234")
  |> should.equal(Ok(Nil))

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)

  file_stream.read_bytes_exact(stream, 2)
  |> should.equal(Ok(<<"Te":utf8>>))

  file_stream.position(stream, file_stream.CurrentLocation(-2))
  |> should.equal(Ok(0))

  file_stream.position(stream, file_stream.CurrentLocation(-2))
  |> should.equal(Error(file_stream_error.Einval))

  file_stream.read_bytes_exact(stream, 2)
  |> should.equal(Ok(<<"Te":utf8>>))

  file_stream.position(stream, file_stream.BeginningOfFile(4))
  |> should.equal(Ok(4))

  file_stream.read_bytes_exact(stream, 4)
  |> should.equal(Ok(<<"1234":utf8>>))

  file_stream.position(stream, file_stream.EndOfFile(-2))
  |> should.equal(Ok(6))

  file_stream.read_bytes_exact(stream, 2)
  |> should.equal(Ok(<<"34":utf8>>))

  file_stream.position(stream, file_stream.EndOfFile(10))
  |> should.equal(Ok(18))

  file_stream.read_bytes_exact(stream, 1)
  |> should.equal(Error(file_stream_error.Eof))

  file_stream.position(stream, file_stream.BeginningOfFile(-100))
  |> should.equal(Error(file_stream_error.Einval))

  file_stream.position(stream, file_stream.CurrentLocation(-100))
  |> should.equal(Error(file_stream_error.Einval))

  file_stream.position(stream, file_stream.BeginningOfFile(6))
  |> should.equal(Ok(6))

  file_stream.read_bytes_exact(stream, 2)
  |> should.equal(Ok(<<"34":utf8>>))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

/// Test reading and writing in the same file stream.
///
pub fn read_write_test() {
  let assert Ok(stream) =
    file_stream.open(tmp_file_name, [
      file_open_mode.Read,
      file_open_mode.Write,
      file_open_mode.Raw,
    ])

  file_stream.write_bytes(stream, <<"Test1234":utf8>>)
  |> should.equal(Ok(Nil))

  file_stream.position(stream, file_stream.CurrentLocation(-4))
  |> should.equal(Ok(4))

  file_stream.read_bytes(stream, 4)
  |> should.equal(Ok(<<"1234":utf8>>))

  file_stream.write_bytes(stream, <<"5678":utf8>>)
  |> should.equal(Ok(Nil))

  file_stream.position(stream, file_stream.BeginningOfFile(14))
  |> should.equal(Ok(14))

  file_stream.write_bytes(stream, <<"9":utf8>>)
  |> should.equal(Ok(Nil))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.read(tmp_file_name)
  |> should.equal(Ok("Test12345678\u{0}\u{0}9"))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

pub fn append_test() {
  simplifile.write(tmp_file_name, "Test1234")
  |> should.equal(Ok(Nil))

  let assert Ok(stream) =
    file_stream.open(tmp_file_name, [
      file_open_mode.Append,
      file_open_mode.Read,
      file_open_mode.Write,
      file_open_mode.Raw,
    ])

  file_stream.write_bytes(stream, <<"5678">>)
  |> should.equal(Ok(Nil))

  file_stream.position(stream, file_stream.BeginningOfFile(0))
  |> should.equal(Ok(0))

  file_stream.read_bytes(stream, 4)
  |> should.equal(Ok(<<"Test">>))

  file_stream.write_bytes(stream, <<"9">>)
  |> should.equal(Ok(Nil))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.read(tmp_file_name)
  |> should.equal(Ok("Test123456789"))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

@target(erlang)
pub fn read_line_read_chars_test() {
  let assert Ok(stream) = file_stream.open_write(tmp_file_name)

  file_stream.write_chars(stream, "Hello\nBoo 👻!\n1🦑234\nLast")
  |> should.equal(Ok(Nil))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)

  file_stream.read_line(stream)
  |> should.equal(Ok("Hello\n"))

  file_stream.read_line(stream)
  |> should.equal(Ok("Boo 👻!\n"))

  file_stream.read_chars(stream, 1)
  |> should.equal(Error(file_stream_error.Enotsup))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  let assert Ok(stream) =
    file_stream.open_read_text(tmp_file_name, text_encoding.Unicode)

  file_stream.read_line(stream)
  |> should.equal(Ok("Hello\n"))

  file_stream.read_line(stream)
  |> should.equal(Ok("Boo 👻!\n"))

  file_stream.read_chars(stream, 1)
  |> should.equal(Ok("1"))

  file_stream.read_chars(stream, 2)
  |> should.equal(Ok("🦑2"))

  file_stream.read_line(stream)
  |> should.equal(Ok("34\n"))

  file_stream.read_chars(stream, 5)
  |> should.equal(Ok("Last"))

  file_stream.read_line(stream)
  |> should.equal(Error(file_stream_error.Eof))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

@target(erlang)
pub fn read_invalid_utf8_test() {
  let invalid_utf8_bytes = <<0xC3, 0x28>>

  simplifile.write_bits(tmp_file_name, invalid_utf8_bytes)
  |> should.equal(Ok(Nil))

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)

  file_stream.read_line(stream)
  |> should.equal(Error(file_stream_error.InvalidUnicode))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  let assert Ok(stream) =
    file_stream.open_read_text(tmp_file_name, text_encoding.Unicode)

  file_stream.read_line(stream)
  |> should.equal(
    Error(file_stream_error.NoTranslation(
      text_encoding.Unicode,
      text_encoding.Unicode,
    )),
  )

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

@target(erlang)
pub fn read_latin1_test() {
  simplifile.write_bits(tmp_file_name, <<0xC3, 0xD4>>)
  |> should.equal(Ok(Nil))

  let assert Ok(stream) =
    file_stream.open_read_text(tmp_file_name, text_encoding.Latin1)

  file_stream.read_bytes(stream, 2)
  |> should.equal(Ok(<<0xC3, 0xD4>>))

  file_stream.position(stream, file_stream.BeginningOfFile(0))
  |> should.equal(Ok(0))

  file_stream.read_chars(stream, 1)
  |> should.equal(Ok("Ã"))

  file_stream.read_line(stream)
  |> should.equal(Ok("Ô"))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

@target(erlang)
pub fn write_latin1_test() {
  let assert Ok(stream) =
    file_stream.open_write_text(tmp_file_name, text_encoding.Latin1)

  file_stream.write_chars(stream, "ÃÔ")
  |> should.equal(Ok(Nil))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.read_bits(tmp_file_name)
  |> should.equal(Ok(<<0xC3, 0xD4>>))

  let assert Ok(stream) =
    file_stream.open_write_text(tmp_file_name, text_encoding.Latin1)

  file_stream.write_chars(stream, "日本")
  |> should.equal(
    Error(file_stream_error.NoTranslation(
      text_encoding.Unicode,
      text_encoding.Latin1,
    )),
  )

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

@target(erlang)
pub fn read_utf16le_test() {
  simplifile.write_bits(tmp_file_name, <<0xE5, 0x65, 0x2C, 0x67, 0x9E, 0x8A>>)
  |> should.equal(Ok(Nil))

  let assert Ok(stream) =
    file_stream.open_read_text(
      tmp_file_name,
      text_encoding.Utf16(text_encoding.Little),
    )

  file_stream.read_chars(stream, 2)
  |> should.equal(Ok("日本"))

  file_stream.read_line(stream)
  |> should.equal(Ok("語"))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

@target(erlang)
pub fn write_utf16le_test() {
  let assert Ok(stream) =
    file_stream.open_write_text(
      tmp_file_name,
      text_encoding.Utf16(text_encoding.Little),
    )

  file_stream.write_chars(stream, "日本語")
  |> should.equal(Ok(Nil))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.read_bits(tmp_file_name)
  |> should.equal(Ok(<<0xE5, 0x65, 0x2C, 0x67, 0x9E, 0x8A>>))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

@target(erlang)
pub fn read_utf32be_test() {
  simplifile.write_bits(tmp_file_name, <<
    0x00, 0x01, 0x03, 0x48, 0xFF, 0xFF, 0xFF, 0xFF,
  >>)
  |> should.equal(Ok(Nil))

  let assert Ok(stream) =
    file_stream.open_read_text(
      tmp_file_name,
      text_encoding.Utf32(text_encoding.Big),
    )

  file_stream.read_chars(stream, 1)
  |> should.equal(Ok("𐍈"))

  file_stream.read_chars(stream, 1)
  |> should.equal(Error(file_stream_error.InvalidUnicode))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

@target(erlang)
pub fn write_utf32be_test() {
  let assert Ok(stream) =
    file_stream.open_write_text(
      tmp_file_name,
      text_encoding.Utf32(text_encoding.Big),
    )

  file_stream.write_chars(stream, "𐍈")
  |> should.equal(Ok(Nil))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.read_bits(tmp_file_name)
  |> should.equal(Ok(<<0x00, 0x01, 0x03, 0x48>>))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

@target(erlang)
pub fn set_encoding_test() {
  let assert Ok(stream) =
    file_stream.open_write_text(tmp_file_name, text_encoding.Latin1)

  file_stream.write_chars(stream, "ÃÔ")
  |> should.equal(Ok(Nil))

  let assert Ok(stream) =
    file_stream.set_encoding(stream, text_encoding.Unicode)

  file_stream.write_chars(stream, "👻")
  |> should.equal(Ok(Nil))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.read_bits(tmp_file_name)
  |> should.equal(Ok(<<0xC3, 0xD4, 0xF0, 0x9F, 0x91, 0xBB>>))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}

pub fn write_partial_bytes_test() {
  let assert Ok(stream) = file_stream.open_write(tmp_file_name)

  file_stream.write_bytes(stream, <<"A", 0:7>>)
  |> should.equal(Error(file_stream_error.Einval))

  file_stream.close(stream)
  |> should.equal(Ok(Nil))

  simplifile.delete(tmp_file_name)
  |> should.equal(Ok(Nil))
}
