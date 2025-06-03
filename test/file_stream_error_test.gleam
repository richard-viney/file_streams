import file_streams/file_stream_error

pub fn describe_test() {
  assert file_stream_error.describe(file_stream_error.Eacces)
    == "Permission denied"
}
