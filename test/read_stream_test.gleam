import file_streams/read_stream
import gleam/bit_array
import gleeunit/should
import simplifile

pub fn read_stream_test() {
  let tmp_file_name = "read_stream_test"

  let assert Ok(Nil) =
    simplifile.write_bits(
      tmp_file_name,
      bit_array.concat([
        <<-100:int-size(8), 200:int-size(8)>>,
        <<
          -3000:little-int-size(16), -3000:big-int-size(16),
          10_000:little-int-size(16), 10_000:big-int-size(16),
        >>,
        <<
          -300_000:little-int-size(32), -300_000:big-int-size(32),
          1_000_000:little-int-size(32), 1_000_000:big-int-size(32),
        >>,
        <<
          -10_000_000_000:little-int-size(64), -10_000_000_000:big-int-size(64),
          100_000_000_000:little-int-size(64), 100_000_000_000:big-int-size(64),
        >>,
        <<
          1.5:little-float-size(32), 1.5:big-float-size(32),
          2.5:little-float-size(64), 2.5:big-float-size(64),
        >>,
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

  read_stream.read_list(rs, read_stream.read_float64_le, 3)
  |> should.equal(Ok([1.0, 2.0, 3.0]))

  read_stream.read_uint8(rs)
  |> should.equal(Error(read_stream.EndOfStream))

  read_stream.close(rs)
  |> should.equal(Nil)

  simplifile.delete(tmp_file_name)
}
