import file_streams/file_encoding
import file_streams/file_error
import file_streams/read_stream_error
import file_streams/read_text_stream
import gleeunit/should
import simplifile

const tmp_file_name = "read_text_stream_test"

pub fn read_text_stream_test() {
  let assert Ok(Nil) =
    simplifile.write(tmp_file_name, "Hello\nBoo 👻!\n1🦑234\nLast")
  let assert Ok(rs) = read_text_stream.open(tmp_file_name)

  read_text_stream.read_line(rs)
  |> should.equal(Ok("Hello\n"))

  read_text_stream.read_line(rs)
  |> should.equal(Ok("Boo 👻!\n"))

  read_text_stream.read_chars(rs, 1)
  |> should.equal(Ok("1"))

  read_text_stream.read_chars(rs, 2)
  |> should.equal(Ok("🦑2"))

  read_text_stream.read_line(rs)
  |> should.equal(Ok("34\n"))

  read_text_stream.read_chars(rs, 5)
  |> should.equal(Ok("Last"))

  read_text_stream.read_line(rs)
  |> should.equal(Error(read_stream_error.EndOfStream))

  simplifile.delete(tmp_file_name)
}

pub fn read_invalid_file_test() {
  let invalid_utf8_bytes = <<0xC3, 0x28>>

  let assert Ok(Nil) = simplifile.write_bits(tmp_file_name, invalid_utf8_bytes)
  let assert Ok(rs) = read_text_stream.open(tmp_file_name)

  read_text_stream.read_line(rs)
  |> should.equal(
    Error(
      read_stream_error.OtherFileError(file_error.NoTranslation(
        file_encoding.Unicode,
        file_encoding.Unicode,
      )),
    ),
  )

  simplifile.delete(tmp_file_name)
}
