import file_streams/read_stream
import file_streams/read_stream_error
import file_streams/write_stream
import gleeunit
import gleeunit/should
import simplifile

pub fn main() {
  gleeunit.main()
}

pub fn file_streams_test() {
  let tmp_file_name = "file_streams_test"

  let assert Ok(ws) = write_stream.open(tmp_file_name)

  write_stream.write_string(ws, "Hello, world!")
  |> should.equal(Ok(Nil))

  write_stream.close(ws)
  |> should.equal(Ok(Nil))

  let assert Ok(rs) = read_stream.open(tmp_file_name)

  read_stream.read_bytes(rs, 5)
  |> should.equal(Ok(<<"Hello":utf8>>))

  read_stream.read_bytes(rs, 3)
  |> should.equal(Ok(<<", w":utf8>>))

  read_stream.read_bytes(rs, 100)
  |> should.equal(Ok(<<"orld!":utf8>>))

  read_stream.read_bytes(rs, 1)
  |> should.equal(Error(read_stream_error.EndOfStream))

  read_stream.close(rs)
  |> should.equal(Nil)

  simplifile.delete(tmp_file_name)
}
