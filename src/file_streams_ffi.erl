-module(file_streams_ffi).
-export([file_read_file_info/1, io_get_line/1, io_get_chars/2, io_put_chars/2]).

-include_lib("kernel/include/file.hrl").

optional(undefined) -> none;
optional(Value) -> {some, Value}.

% Wraps file:read_file_info to wrap `file_info()` fields in `Option` and rename
% the `type` field to `type_`.  Actually, since the Erlang and Gleam records
% share the same name but have different shapes, we proxy the fields of the
% Erlang record through a tuple and rewrap it in Gleam.
%
file_read_file_info(Device) ->
    case file:read_file_info(Device, [{time, posix}]) of
	{ok, FileInfo} -> {ok, {
	    optional(FileInfo#file_info.size),
	    optional(FileInfo#file_info.type),
	    optional(FileInfo#file_info.access),
	    optional(FileInfo#file_info.atime),
	    optional(FileInfo#file_info.mtime),
	    optional(FileInfo#file_info.ctime),
	    optional(FileInfo#file_info.mode),
	    optional(FileInfo#file_info.links),
	    optional(FileInfo#file_info.major_device),
	    optional(FileInfo#file_info.minor_device),
	    optional(FileInfo#file_info.inode),
	    optional(FileInfo#file_info.uid),
	    optional(FileInfo#file_info.gid)}};
	{error, Error} -> {error, Error}
    end.

% Wraps io:get_line to return `{ok, Data}` on success instead of just `Data`
%
io_get_line(Device) ->
    case io:get_line(Device, "") of
        eof -> eof;
        {error, Reason} -> {error, Reason};
        Data -> {ok, Data}
    end.

% Wraps io:get_chars to return `{ok, Data}` on success instead of just `Data`
%
io_get_chars(Device, Count) ->
    case io:get_chars(Device, "", Count) of
        eof -> eof;
        {error, Reason} -> {error, Reason};
        Data -> {ok, Data}
    end.

% Wraps io:put_chars to return `{ok, nil}` on success instead of just `ok`, and
% to return the no_translation exception as an error.
%
io_put_chars(Device, CharData) ->
    try
        case io:put_chars(Device, CharData) of
            ok -> {ok, nil};
            {error, Reason} -> {error, Reason}
        end
    catch
        error:no_translation -> {error, {no_translation, unicode, latin1}}
    end.
