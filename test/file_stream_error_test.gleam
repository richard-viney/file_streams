import file_streams/file_stream_error
import gleeunit/should

pub fn describe_test() {
  file_stream_error.describe(file_stream_error.Eacces)
  |> should.equal("Permission denied")
}
