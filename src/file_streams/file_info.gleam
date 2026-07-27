import gleam/option.{type Option}

import file_streams/file_access.{type FileAccess}
import file_streams/file_type.{type FileType}

/// The info that can be obtained for a file stream with
/// [`file_stream.read_file_info()`](./file_stream.html#read_file_info).
///
pub type FileInfo {
  FileInfo(
    size: Option(Int),
    type_: Option(FileType),
    access: Option(FileAccess),
    atime: Option(Int),
    mtime: Option(Int),
    ctime: Option(Int),
    mode: Option(Int),
    links: Option(Int),
    major_device: Option(Int),
    minor_device: Option(Int),
    inode: Option(Int),
    uid: Option(Int),
    gid: Option(Int),
  )
}
