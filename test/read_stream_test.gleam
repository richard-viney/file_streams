import file_streams/file_error
import file_streams/read_stream
import file_streams/read_stream_error
import gleam/bit_array
import gleam/string
import gleeunit/should
import simplifile

const tmp_file_name = "read_stream.test"

pub fn read_stream_test() {
  let assert Ok(Nil) =
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
          -10_000_000_000:little-int-size(64), -10_000_000_000:big-int-size(64),
          100_000_000_000:little-int-size(64), 100_000_000_000:big-int-size(64),
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

  let assert Ok(rs) = read_stream.open(tmp_file_name)

  read_stream.read_int8(rs)
  |> should.equal(Ok(-100))

  read_stream.read_uint8(rs)
  |> should.equal(Ok(200))

  read_stream.read_int16_le(rs)
  |> should.equal(Ok(-3000))
  read_stream.read_int16_be(rs)
  |> should.equal(Ok(-3000))

  read_stream.read_uint16_le(rs)
  |> should.equal(Ok(10_000))
  read_stream.read_uint16_be(rs)
  |> should.equal(Ok(10_000))

  read_stream.read_int32_le(rs)
  |> should.equal(Ok(-300_000))
  read_stream.read_int32_be(rs)
  |> should.equal(Ok(-300_000))

  read_stream.read_uint32_le(rs)
  |> should.equal(Ok(1_000_000))
  read_stream.read_uint32_be(rs)
  |> should.equal(Ok(1_000_000))

  read_stream.read_int64_le(rs)
  |> should.equal(Ok(-10_000_000_000))
  read_stream.read_int64_be(rs)
  |> should.equal(Ok(-10_000_000_000))

  read_stream.read_uint64_le(rs)
  |> should.equal(Ok(100_000_000_000))
  read_stream.read_uint64_be(rs)
  |> should.equal(Ok(100_000_000_000))

  read_stream.read_float32_le(rs)
  |> should.equal(Ok(1.5))
  read_stream.read_float32_be(rs)
  |> should.equal(Ok(1.5))

  read_stream.read_float64_le(rs)
  |> should.equal(Ok(2.5))
  read_stream.read_float64_be(rs)
  |> should.equal(Ok(2.5))

  read_stream.read_list(rs, read_stream.read_float64_le, 2)
  |> should.equal(Ok([1.0, 2.0]))

  read_stream.read_bytes_exact(rs, 9)
  |> should.equal(Error(read_stream_error.EndOfStream))

  read_stream.close(rs)
  |> should.equal(Ok(Nil))

  let assert Ok(Nil) = simplifile.delete(tmp_file_name)
}

pub fn read_remaining_bytes_test() {
  let assert Ok(_) =
    simplifile.write(tmp_file_name, string.repeat("Test", 50_000))

  let assert Ok(rs) = read_stream.open(tmp_file_name)
  let assert Ok(_) = read_stream.read_bytes_exact(rs, 100_000)

  let assert Ok(remaining_bytes) = read_stream.read_remaining_bytes(rs)

  remaining_bytes
  |> bit_array.to_string
  |> should.equal(Ok(string.repeat("Test", 25_000)))
}

pub fn position_test() {
  let assert Ok(_) = simplifile.write(tmp_file_name, "Test1234")

  let assert Ok(rs) = read_stream.open(tmp_file_name)

  let assert Ok(<<"Te":utf8>>) = read_stream.read_bytes_exact(rs, 2)

  let assert Ok(0) = read_stream.position(rs, read_stream.CurrentLocation(-2))
  let assert Ok(<<"Te":utf8>>) = read_stream.read_bytes_exact(rs, 2)

  let assert Ok(4) = read_stream.position(rs, read_stream.BeginningOfFile(4))
  let assert Ok(<<"1234":utf8>>) = read_stream.read_bytes_exact(rs, 4)

  let assert Ok(6) = read_stream.position(rs, read_stream.EndOfFile(-2))
  let assert Ok(<<"34":utf8>>) = read_stream.read_bytes_exact(rs, 2)

  let assert Ok(18) = read_stream.position(rs, read_stream.EndOfFile(10))
  let assert Error(read_stream_error.EndOfStream) =
    read_stream.read_bytes_exact(rs, 1)

  let assert Error(file_error.Einval) =
    read_stream.position(rs, read_stream.BeginningOfFile(-100))

  let assert Error(file_error.Einval) =
    read_stream.position(rs, read_stream.CurrentLocation(-100))

  let assert Ok(6) = read_stream.position(rs, read_stream.BeginningOfFile(6))
  let assert Ok(<<"34":utf8>>) = read_stream.read_bytes_exact(rs, 2)
}
