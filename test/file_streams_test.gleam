import file_streams/file_open_mode
import file_streams/file_stream
import file_streams/file_stream_error
@target(erlang)
import file_streams/text_encoding
import gleam/bit_array
import gleam/string
import gleeunit
import simplifile

const tmp_file_name = "file_streams.test"

pub fn main() {
  gleeunit.main()
}

pub fn open_missing_file_test() {
  assert file_stream.open_read("missing_file.txt")
    == Error(file_stream_error.Enoent)
}

pub fn open_directory_test() {
  assert file_stream.open_read("src") == Error(file_stream_error.Eisdir)
}

pub fn read_ints_and_floats_test() {
  assert simplifile.write_bits(
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
    == Ok(Nil)

  let assert Ok(stream) =
    file_stream.open(tmp_file_name, [file_open_mode.Read, file_open_mode.Raw])

  assert file_stream.read_int8(stream) == Ok(-100)

  assert file_stream.read_uint8(stream) == Ok(200)

  assert file_stream.read_int16_le(stream) == Ok(-3000)
  assert file_stream.read_int16_be(stream) == Ok(-3000)

  assert file_stream.read_uint16_le(stream) == Ok(10_000)
  assert file_stream.read_uint16_be(stream) == Ok(10_000)

  assert file_stream.read_int32_le(stream) == Ok(-300_000)
  assert file_stream.read_int32_be(stream) == Ok(-300_000)

  assert file_stream.read_uint32_le(stream) == Ok(1_000_000)
  assert file_stream.read_uint32_be(stream) == Ok(1_000_000)

  assert file_stream.read_uint64_le(stream) == Ok(9_007_199_254_740_991)
  assert file_stream.read_uint64_be(stream) == Ok(9_007_199_254_740_991)

  assert file_stream.read_float32_le(stream) == Ok(1.5)
  assert file_stream.read_float32_be(stream) == Ok(1.5)

  assert file_stream.read_float64_le(stream) == Ok(2.5)
  assert file_stream.read_float64_be(stream) == Ok(2.5)

  assert file_stream.read_list(stream, file_stream.read_float64_le, 2)
    == Ok([1.0, 2.0])

  assert file_stream.position(stream, file_stream.BeginningOfFile(83)) == Ok(83)
  assert file_stream.read_bytes_exact(stream, 0) == Ok(<<>>)

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

pub fn read_bytes_exact_test() {
  assert simplifile.write(tmp_file_name, "Test") == Ok(Nil)

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)

  assert file_stream.read_bytes_exact(stream, 2) == Ok(<<"Te":utf8>>)
  assert file_stream.read_bytes_exact(stream, 3) == Error(file_stream_error.Eof)

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

pub fn read_remaining_bytes_test() {
  assert simplifile.write(tmp_file_name, string.repeat("Test", 50_000))
    == Ok(Nil)

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)
  let assert Ok(_) = file_stream.read_bytes_exact(stream, 100_000)

  let assert Ok(remaining_bytes) = file_stream.read_remaining_bytes(stream)

  assert bit_array.to_string(remaining_bytes)
    == Ok(string.repeat("Test", 25_000))

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

pub fn position_test() {
  assert simplifile.write(tmp_file_name, "Test1234") == Ok(Nil)

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)

  assert file_stream.read_bytes_exact(stream, 2) == Ok(<<"Te":utf8>>)

  assert file_stream.position(stream, file_stream.CurrentLocation(-2)) == Ok(0)
  assert file_stream.position(stream, file_stream.CurrentLocation(-2))
    == Error(file_stream_error.Einval)
  assert file_stream.read_bytes_exact(stream, 2) == Ok(<<"Te":utf8>>)

  assert file_stream.position(stream, file_stream.BeginningOfFile(4)) == Ok(4)
  assert file_stream.read_bytes_exact(stream, 4) == Ok(<<"1234":utf8>>)

  assert file_stream.position(stream, file_stream.EndOfFile(-2)) == Ok(6)
  assert file_stream.read_bytes_exact(stream, 2) == Ok(<<"34":utf8>>)

  assert file_stream.position(stream, file_stream.EndOfFile(10)) == Ok(18)
  assert file_stream.read_bytes_exact(stream, 1) == Error(file_stream_error.Eof)

  assert file_stream.position(stream, file_stream.BeginningOfFile(-100))
    == Error(file_stream_error.Einval)
  assert file_stream.position(stream, file_stream.CurrentLocation(-100))
    == Error(file_stream_error.Einval)
  assert file_stream.position(stream, file_stream.BeginningOfFile(6)) == Ok(6)
  assert file_stream.read_bytes_exact(stream, 2) == Ok(<<"34":utf8>>)

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
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

  assert file_stream.write_bytes(stream, <<"Test1234":utf8>>) == Ok(Nil)

  assert file_stream.position(stream, file_stream.CurrentLocation(-4)) == Ok(4)
  assert file_stream.read_bytes(stream, 4) == Ok(<<"1234":utf8>>)
  assert file_stream.write_bytes(stream, <<"5678":utf8>>) == Ok(Nil)
  assert file_stream.position(stream, file_stream.BeginningOfFile(14)) == Ok(14)
  assert file_stream.write_bytes(stream, <<"9":utf8>>) == Ok(Nil)

  assert file_stream.close(stream) == Ok(Nil)

  assert simplifile.read(tmp_file_name) == Ok("Test12345678\u{0}\u{0}9")
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

pub fn append_test() {
  assert simplifile.write(tmp_file_name, "Test1234") == Ok(Nil)

  let assert Ok(stream) =
    file_stream.open(tmp_file_name, [
      file_open_mode.Append,
      file_open_mode.Read,
      file_open_mode.Write,
      file_open_mode.Raw,
    ])

  assert file_stream.write_bytes(stream, <<"5678">>) == Ok(Nil)
  assert file_stream.position(stream, file_stream.BeginningOfFile(0)) == Ok(0)
  assert file_stream.read_bytes(stream, 4) == Ok(<<"Test">>)
  assert file_stream.write_bytes(stream, <<"9">>) == Ok(Nil)
  assert file_stream.close(stream) == Ok(Nil)

  assert simplifile.read(tmp_file_name) == Ok("Test123456789")
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

@target(erlang)
pub fn read_line_read_chars_test() {
  let assert Ok(stream) = file_stream.open_write(tmp_file_name)

  assert file_stream.write_chars(stream, "Hello\nBoo 👻!\n1🦑234\nLast")
    == Ok(Nil)
  assert file_stream.close(stream) == Ok(Nil)

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)

  assert file_stream.read_line(stream) == Ok("Hello\n")
  assert file_stream.read_line(stream) == Ok("Boo 👻!\n")
  assert file_stream.read_chars(stream, 1) == Error(file_stream_error.Enotsup)
  assert file_stream.close(stream) == Ok(Nil)

  let assert Ok(stream) =
    file_stream.open_read_text(tmp_file_name, text_encoding.Unicode)

  assert file_stream.read_line(stream) == Ok("Hello\n")
  assert file_stream.read_line(stream) == Ok("Boo 👻!\n")
  assert file_stream.read_chars(stream, 1) == Ok("1")
  assert file_stream.read_chars(stream, 2) == Ok("🦑2")
  assert file_stream.read_line(stream) == Ok("34\n")
  assert file_stream.read_chars(stream, 5) == Ok("Last")
  assert file_stream.read_line(stream) == Error(file_stream_error.Eof)

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

@target(erlang)
pub fn read_invalid_utf8_test() {
  let invalid_utf8_bytes = <<0xC3, 0x28>>

  assert simplifile.write_bits(tmp_file_name, invalid_utf8_bytes) == Ok(Nil)

  let assert Ok(stream) = file_stream.open_read(tmp_file_name)

  assert file_stream.read_line(stream)
    == Error(file_stream_error.InvalidUnicode)
  assert file_stream.close(stream) == Ok(Nil)

  let assert Ok(stream) =
    file_stream.open_read_text(tmp_file_name, text_encoding.Unicode)

  assert file_stream.read_line(stream)
    == Error(file_stream_error.NoTranslation(
      text_encoding.Unicode,
      text_encoding.Unicode,
    ))

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

@target(erlang)
pub fn read_latin1_test() {
  assert simplifile.write_bits(tmp_file_name, <<0xC3, 0xD4>>) == Ok(Nil)

  let assert Ok(stream) =
    file_stream.open_read_text(tmp_file_name, text_encoding.Latin1)

  assert file_stream.read_bytes(stream, 2) == Ok(<<0xC3, 0xD4>>)
  assert file_stream.position(stream, file_stream.BeginningOfFile(0)) == Ok(0)
  assert file_stream.read_chars(stream, 1) == Ok("Ã")
  assert file_stream.read_line(stream) == Ok("Ô")

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

@target(erlang)
pub fn write_latin1_test() {
  let assert Ok(stream) =
    file_stream.open_write_text(tmp_file_name, text_encoding.Latin1)

  assert file_stream.write_chars(stream, "ÃÔ") == Ok(Nil)
  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.read_bits(tmp_file_name) == Ok(<<0xC3, 0xD4>>)

  let assert Ok(stream) =
    file_stream.open_write_text(tmp_file_name, text_encoding.Latin1)

  assert file_stream.write_chars(stream, "日本")
    == Error(file_stream_error.NoTranslation(
      text_encoding.Unicode,
      text_encoding.Latin1,
    ))

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

@target(erlang)
pub fn read_utf16le_test() {
  assert simplifile.write_bits(tmp_file_name, <<
      0xE5, 0x65, 0x2C, 0x67, 0x9E, 0x8A,
    >>)
    == Ok(Nil)

  let assert Ok(stream) =
    file_stream.open_read_text(
      tmp_file_name,
      text_encoding.Utf16(text_encoding.Little),
    )

  assert file_stream.read_chars(stream, 2) == Ok("日本")
  assert file_stream.read_line(stream) == Ok("語")

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

@target(erlang)
pub fn write_utf16le_test() {
  let assert Ok(stream) =
    file_stream.open_write_text(
      tmp_file_name,
      text_encoding.Utf16(text_encoding.Little),
    )

  assert file_stream.write_chars(stream, "日本語") == Ok(Nil)
  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.read_bits(tmp_file_name)
    == Ok(<<0xE5, 0x65, 0x2C, 0x67, 0x9E, 0x8A>>)

  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

@target(erlang)
pub fn read_utf32be_test() {
  assert simplifile.write_bits(tmp_file_name, <<
      0x00, 0x01, 0x03, 0x48, 0xFF, 0xFF, 0xFF, 0xFF,
    >>)
    == Ok(Nil)

  let assert Ok(stream) =
    file_stream.open_read_text(
      tmp_file_name,
      text_encoding.Utf32(text_encoding.Big),
    )

  assert file_stream.read_chars(stream, 1) == Ok("𐍈")
  assert file_stream.read_chars(stream, 1)
    == Error(file_stream_error.InvalidUnicode)

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

@target(erlang)
pub fn write_utf32be_test() {
  let assert Ok(stream) =
    file_stream.open_write_text(
      tmp_file_name,
      text_encoding.Utf32(text_encoding.Big),
    )

  assert file_stream.write_chars(stream, "𐍈") == Ok(Nil)
  assert file_stream.close(stream) == Ok(Nil)

  assert simplifile.read_bits(tmp_file_name) == Ok(<<0x00, 0x01, 0x03, 0x48>>)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

@target(erlang)
pub fn set_encoding_test() {
  let assert Ok(stream) =
    file_stream.open_write_text(tmp_file_name, text_encoding.Latin1)

  assert file_stream.write_chars(stream, "ÃÔ") == Ok(Nil)

  let assert Ok(stream) =
    file_stream.set_encoding(stream, text_encoding.Unicode)

  assert file_stream.write_chars(stream, "👻") == Ok(Nil)
  assert file_stream.close(stream) == Ok(Nil)

  assert simplifile.read_bits(tmp_file_name)
    == Ok(<<0xC3, 0xD4, 0xF0, 0x9F, 0x91, 0xBB>>)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}

pub fn write_partial_bytes_test() {
  let assert Ok(stream) = file_stream.open_write(tmp_file_name)

  assert file_stream.write_bytes(stream, <<"A", 0:7>>)
    == Error(file_stream_error.Einval)

  assert file_stream.close(stream) == Ok(Nil)
  assert simplifile.delete(tmp_file_name) == Ok(Nil)
}
