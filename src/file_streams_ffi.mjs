import {
  closeSync,
  existsSync,
  fsyncSync,
  openSync,
  readSync,
  statSync,
  writeSync,
} from "node:fs";
import { BitArray$BitArray, Result$Ok, Result$Error } from "./gleam.mjs";
import {
  FileOpenMode$isAppend,
  FileOpenMode$isEncoding,
  FileOpenMode$isRead,
  FileOpenMode$isWrite,
} from "./file_streams/file_open_mode.mjs";
import {
  Location$isCur,
  Location$isEof,
} from "./file_streams/internal/raw_location.mjs";
import * as raw_result from "./file_streams/internal/raw_result.mjs";
import {
  RawReadResult$Eof,
  RawReadResult$Error,
  RawReadResult$Ok,
} from "./file_streams/internal/raw_read_result.mjs";
import {
  FileStreamError$Eacces,
  FileStreamError$Ebadf,
  FileStreamError$Eexist,
  FileStreamError$Einval,
  FileStreamError$Eio,
  FileStreamError$Eisdir,
  FileStreamError$Emfile,
  FileStreamError$Enfile,
  FileStreamError$Enodev,
  FileStreamError$Enoent,
  FileStreamError$Enospc,
  FileStreamError$Enotdir,
  FileStreamError$Enotsup,
  FileStreamError$Eperm,
  FileStreamError$Erofs,
  FileStreamError$Etxtbsy,
} from "./file_streams/file_stream_error.mjs";

export function file_open(filename, mode) {
  try {
    let size = 0;

    try {
      const stats = statSync(filename);

      // Return an error if the filename is a directory
      if (stats.isDirectory()) {
        return Result$Error(FileStreamError$Eisdir());
      }

      // Store size of the file if it exists so that seeks done relative to the
      // end of the file are possible
      size = stats.size;
    } catch {}

    // Read relevant settings from the mode
    mode = mode.toArray();
    let mode_read = mode.some((mode) => FileOpenMode$isRead(mode));
    let mode_write = mode.some((mode) => FileOpenMode$isWrite(mode));
    let mode_append = mode.some((mode) => FileOpenMode$isAppend(mode));

    // Append implies write
    mode_write ||= mode_append;

    // Default to read
    if (!mode_read && !mode_write) {
      mode_read = true;
    }

    // Text encodings are not supported on JavaScript
    if (mode.some(FileOpenMode$isEncoding)) {
      return Result$Error(FileStreamError$Enotsup());
    }

    // Determine the mode string
    let mode_string;
    if (mode_write) {
      if (mode_read) {
        if (existsSync(filename)) {
          mode_string = "r+";
        } else {
          mode_string = "w+";
        }
      } else {
        mode_string = "w";
      }
    } else {
      mode_string = "r";
    }

    // Open the file
    const fd = openSync(filename, mode_string);

    const io_device = {
      fd,
      position: 0,
      size,
      mode_append,
    };

    return Result$Ok(io_device);
  } catch (e) {
    return Result$Error(map_error(e));
  }
}

export function file_read(io_device, byte_count) {
  try {
    // Reading zero bytes always succeeds
    if (byte_count === 0) {
      return RawReadResult$Ok(BitArray$BitArray(new Uint8Array()));
    }

    // Read bytes at the current position
    let buffer = new Uint8Array(byte_count);
    const bytes_read = readSync(
      io_device.fd,
      buffer,
      0,
      byte_count,
      io_device.position,
    );

    // Advance the current position
    io_device.position += bytes_read;

    // Return eof if nothing was read
    if (bytes_read === 0) {
      return RawReadResult$Eof();
    }

    // Convert result to a BitArray
    let final_buffer = buffer;
    if (bytes_read < byte_count) {
      final_buffer = buffer.slice(0, bytes_read);
    }
    const bit_array = BitArray$BitArray(final_buffer);

    return RawReadResult$Ok(bit_array);
  } catch (e) {
    return RawReadResult$Error(map_error(e));
  }
}

export function file_write(io_device, data) {
  if (data.bitSize % 8 !== 0) {
    return new raw_result.Error(FileStreamError$Einval());
  }

  try {
    const position = io_device.mode_append
      ? io_device.size
      : io_device.position;

    let buffer = data.rawBuffer;
    if (data.bitOffset !== 0) {
      buffer = new Uint8Array(data.byteSize);
      for (let i = 0; i < data.byteSize; i++) {
        buffer[i] = data.byteAt(i);
      }
    }

    // Write data to the file
    const bytes_written = writeSync(
      io_device.fd,
      buffer,
      0,
      buffer.length,
      position,
    );

    // Update the file's size and position depending if it is in append mode
    if (io_device.mode_append) {
      io_device.size += bytes_written;
    } else {
      io_device.position += bytes_written;
      if (io_device.position > io_device.size) {
        io_device.size = io_device.position;
      }
    }

    // Check for an incomplete write
    if (bytes_written !== data.byteSize) {
      return new raw_result.Error(FileStreamError$Enospc());
    }

    return new raw_result.Ok();
  } catch (e) {
    return new raw_result.Error(map_error(e));
  }
}

export function file_close(io_device) {
  try {
    closeSync(io_device.fd);

    io_device.fd = -1;

    return new raw_result.Ok();
  } catch (e) {
    return new raw_result.Error(map_error(e));
  }
}

export function file_position(io_device, location) {
  let new_position = location.offset;
  if (Location$isEof(location)) {
    new_position += io_device.size;
  } else if (Location$isCur(location)) {
    new_position += io_device.position;
  }

  if (new_position < 0) {
    return Result$Error(FileStreamError$Einval());
  }

  io_device.position = new_position;

  return Result$Ok(io_device.position);
}

export function file_sync(io_device) {
  try {
    fsyncSync(io_device.fd);

    return Result$Ok(undefined);
  } catch (e) {
    return Result$Error(map_error(e));
  }
}

//
// Functions that work with encoded text aren't supported on JavaScript. It
// is likely possible to implement this in future if someone is interested.
//

export function file_read_line(_io_device) {
  return RawReadResult$Error(FileStreamError$Enotsup());
}

export function io_get_line(_io_device) {
  return RawReadResult$Error(FileStreamError$Enotsup());
}

export function io_get_chars(_io_device, _char_data) {
  return RawReadResult$Error(FileStreamError$Enotsup());
}

export function io_put_chars(_io_device, _char_data) {
  return Result$Error(FileStreamError$Enotsup());
}

export function io_setopts(_io_device) {
  return new raw_result.Error(FileStreamError$Enotsup());
}

function map_error(error) {
  switch (error.code) {
    case "EACCES":
      return FileStreamError$Eacces();
    case "EBADF":
      return FileStreamError$Ebadf();
    case "EEXIST":
      return FileStreamError$Eexist();
    case "EISDIR":
      return FileStreamError$Eisdir();
    case "EMFILE":
      return FileStreamError$Emfile();
    case "ENOENT":
      return FileStreamError$Enoent();
    case "ENOTDIR":
      return FileStreamError$Enotdir();
    case "ENOSPC":
      return FileStreamError$Enospc();
    case "EPERM":
      return FileStreamError$Eperm();
    case "EROFS":
      return FileStreamError$Erofs();
    case "EIO":
      return FileStreamError$Eio();
    case "ENODEV":
      return FileStreamError$Enodev();
    case "ETXTBSY":
      return FileStreamError$Etxtbsy();
    case "EINVAL":
      return FileStreamError$Einval();
    case "EIO":
      return FileStreamError$Eio();
    case "ENFILE":
      return FileStreamError$Enfile();
    case undefined:
      throw `Undefined error code for error: ${error}`;
    default:
      throw `Unrecognized error code: ${error.code}`;
  }
}
