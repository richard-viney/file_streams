import {
  closeSync,
  existsSync,
  fsyncSync,
  openSync,
  readSync,
  statSync,
  writeSync,
} from "node:fs";
import { BitArray, Ok, Error } from "./gleam.mjs";
import * as file_open_mode from "./file_streams/file_open_mode.mjs";
import * as raw_location from "./file_streams/internal/raw_location.mjs";
import * as raw_result from "./file_streams/internal/raw_result.mjs";
import * as raw_read_result from "./file_streams/internal/raw_read_result.mjs";
import * as file_stream_error from "./file_streams/file_stream_error.mjs";

export function file_open(filename, mode) {
  try {
    let size = 0;

    try {
      const stats = statSync(filename);

      // Return an error if the filename is a directory
      if (stats.isDirectory()) {
        return new Error(new file_stream_error.Eisdir());
      }

      // Store size of the file if it exists so that seeks done relative to the
      // end of the file are possible
      size = stats.size;
    } catch {}

    // Read relevant settings from the mode
    mode = mode.toArray();
    let mode_read = mode.some((mode) => mode instanceof file_open_mode.Read);
    let mode_write = mode.some((mode) => mode instanceof file_open_mode.Write);
    let mode_append = mode.some(
      (mode) => mode instanceof file_open_mode.Append
    );

    // Append implies write
    mode_write ||= mode_append;

    // Default to read
    if (!mode_read && !mode_write) {
      mode_read = true;
    }

    // Text encodings are not supported on JavaScript
    if (mode.some((mode) => mode instanceof file_open_mode.Encoding)) {
      return new Error(new file_stream_error.Enotsup());
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

    return new Ok(io_device);
  } catch (e) {
    return new Error(map_error(e));
  }
}

export function file_read(io_device, byte_count) {
  try {
    // Reading zero bytes always succeeds
    if (byte_count === 0) {
      return new raw_read_result.Ok(new BitArray(new Uint8Array()));
    }

    // Read bytes at the current position
    let buffer = new Uint8Array(byte_count);
    const bytes_read = readSync(
      io_device.fd,
      buffer,
      0,
      byte_count,
      io_device.position
    );

    // Advance the current position
    io_device.position += bytes_read;

    // Return eof if nothing was read
    if (bytes_read === 0) {
      return new raw_read_result.Eof();
    }

    // Convert result to a BitArray
    let final_buffer = buffer;
    if (bytes_read < byte_count) {
      final_buffer = buffer.slice(0, bytes_read);
    }
    const bit_array = new BitArray(final_buffer);

    return new raw_read_result.Ok(bit_array);
  } catch (e) {
    return new raw_read_result.Error(map_error(e));
  }
}

export function file_write(io_device, data) {
  try {
    const position = io_device.mode_append
      ? io_device.size
      : io_device.position;

    // Write data to the file
    const bytes_written = writeSync(
      io_device.fd,
      data.buffer,
      0,
      data.length,
      position
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
    if (bytes_written !== data.length) {
      return new raw_result.Error(new file_stream_error.Enospc());
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
  if (location instanceof raw_location.Eof) {
    new_position += io_device.size;
  } else if (location instanceof raw_location.Cur) {
    new_position += io_device.position;
  }

  if (new_position < 0) {
    return new Error(new file_stream_error.Einval());
  }

  io_device.position = new_position;

  return new Ok(io_device.position);
}

export function file_sync(io_device) {
  try {
    fsyncSync(io_device.fd);

    return new Ok(undefined);
  } catch (e) {
    return new Error(map_error(e));
  }
}

//
// Functions that work with encoded text aren't supported on JavaScript. It
// is likely possible to implement this in future if someone is interested.
//

export function file_read_line(_io_device) {
  return new raw_read_result.Error(new file_stream_error.Enotsup());
}

export function io_get_line(_io_device) {
  return new raw_read_result.Error(new file_stream_error.Enotsup());
}

export function io_get_chars(_io_device, _char_data) {
  return new raw_read_result.Error(new file_stream_error.Enotsup());
}

export function io_put_chars(_io_device, _char_data) {
  return new Error(new file_stream_error.Enotsup());
}

export function io_setopts(_io_device) {
  return new raw_result.Error(new file_stream_error.Enotsup());
}

function map_error(error) {
  switch (error.code) {
    case "EACCES":
      return new file_stream_error.Eacces();
    case "EBADF":
      return new file_stream_error.Ebadf();
    case "EEXIST":
      return new file_stream_error.Eexist();
    case "EISDIR":
      return new file_stream_error.Eisdir();
    case "EMFILE":
      return new file_stream_error.Emfile();
    case "ENOENT":
      return new file_stream_error.Enoent();
    case "ENOTDIR":
      return new file_stream_error.Enotdir();
    case "ENOSPC":
      return new file_stream_error.Enospc();
    case "EPERM":
      return new file_stream_error.Eperm();
    case "EROFS":
      return new file_stream_error.Erofs();
    case "EIO":
      return new file_stream_error.Eio();
    case "ENODEV":
      return new file_stream_error.Enodev();
    case "ETXTBSY":
      return new file_stream_error.Etxtbsy();
    case "EINVAL":
      return new file_stream_error.Einval();
    case "EIO":
      return new file_stream_error.Eio();
    case "ENFILE":
      return new file_stream_error.Enfile();
    case undefined:
      throw `Undefined error code for error: ${error}`;
    default:
      throw `Unrecognized error code: ${error.code}`;
  }
}
