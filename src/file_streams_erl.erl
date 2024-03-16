-module(file_streams_erl).
-export([io_get_line/1, io_get_chars/2]).

% Wraps io:get_line to return `{ok, Data}` on success instead of just `Data`
io_get_line(Device) ->
    case io:get_line(Device, "") of
        eof -> eof;
        {error, Reason} -> {error, Reason};
        Data -> {ok, Data}
    end.

% Wraps io:get_chars to return `{ok, Data}` on success instead of just `Data`
io_get_chars(Device, Count) ->
    case io:get_chars(Device, "", Count) of
        eof -> eof;
        {error, Reason} -> {error, Reason};
        Data -> {ok, Data}
    end.
