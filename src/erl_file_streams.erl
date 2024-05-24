-module(erl_file_streams).
-export([io_get_line/1, io_get_chars/2, io_put_chars/2]).

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

