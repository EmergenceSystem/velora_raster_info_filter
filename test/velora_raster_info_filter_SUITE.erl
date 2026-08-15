-module(velora_raster_info_filter_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([forwards_intent_and_returns_cards/1, velora_down_returns_empty/1]).

all() ->
    [forwards_intent_and_returns_cards, velora_down_returns_empty].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(inets),
    {ok, _} = application:ensure_all_started(velora_raster_info_filter),
    Config.

end_per_suite(_Config) ->
    application:stop(velora_raster_info_filter),
    ok.

%% POST a place query; the stub velora echoes intent+query back. Assert the
%% filter forwarded intent "info" and returned the stub's card.
forwards_intent_and_returns_cards(_Config) ->
    start_stub(),
    try
        {ok, {{_, 200, _}, _, Resp}} = query_filter(<<"{\"query\":\"paris\"}">>),
        #{<<"results">> := [Card | _]} = json:decode(Resp),
        ?assertEqual(<<"info">>, maps:get(<<"intent">>, Card)),
        ?assertEqual(<<"paris">>, maps:get(<<"query">>, Card)),
        ?assertEqual(<<"stub">>,  maps:get(<<"id">>, Card))
    after
        stop_stub()
    end.

%% With no velora reachable, the filter forward fails and returns [].
velora_down_returns_empty(_Config) ->
    {ok, {{_, 200, _}, _, Resp}} = query_filter(<<"{\"query\":\"paris\"}">>),
    #{<<"results">> := R} = json:decode(Resp),
    ?assertEqual([], R).

%%--------------------------------------------------------------------
query_filter(Body) ->
    httpc:request(post,
        {"http://127.0.0.1:19215/agent/query", [], "application/json",
         binary_to_list(Body)},
        [{timeout, 10000}], [{body_format, binary}]).

start_stub() ->
    Dispatch = cowboy_router:compile([
        {'_', [{"/agent/query", velora_raster_info_filter_stub_h, []}]}]),
    {ok, _} = cowboy:start_clear(velora_raster_info_stub_listener,
                                 [{port, 18082}],
                                 #{env => #{dispatch => Dispatch}}).

stop_stub() ->
    catch cowboy:stop_listener(velora_raster_info_stub_listener),
    ok.
