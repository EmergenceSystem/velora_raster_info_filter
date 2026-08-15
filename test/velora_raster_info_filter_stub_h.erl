%%% @doc Test-only stub standing in for a velora node. Echoes the received
%%% intent and query back inside a results card so the SUITE can assert the
%%% filter forwarded them correctly.
-module(velora_raster_info_filter_stub_h).
-export([init/2]).

init(Req0, State) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    In = try json:decode(Body) catch _:_ -> #{} end,
    Intent = maps:get(<<"intent">>, In, <<"?">>),
    Query  = maps:get(<<"query">>, In, <<"?">>),
    Resp = iolist_to_binary(json:encode(#{<<"results">> => [
        #{<<"type">> => <<"info">>, <<"intent">> => Intent,
          <<"query">> => Query, <<"id">> => <<"stub">>}]})),
    Req2 = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>}, Resp, Req1),
    {ok, Req2, State}.
