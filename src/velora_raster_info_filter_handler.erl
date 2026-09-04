%%%-------------------------------------------------------------------
%%% @doc velora_raster_info_filter handler — forwards the query to velora.
%%%
%%% query/1 POSTs {"query": Q, "intent": "info"} to the configured velora
%%% /agent/query endpoint and returns velora's `results' list (info cards).
%%% Any failure (velora down, non-200, malformed body) yields an empty list,
%%% so the mesh degrades gracefully. velora itself does all the GDAL/COG
%%% introspection; this filter is a thin relay.
%%% @end
%%%-------------------------------------------------------------------
-module(velora_raster_info_filter_handler).
-export([query/1, handle/2]).

-define(INTENT, <<"info">>).

%% @doc Forward the query to velora and return its result cards.
-spec query(binary()) -> [map()].
query(Query) when is_binary(Query) ->
    Url  = application:get_env(velora_raster_info_filter, velora_url,
                               "http://127.0.0.1:8081/agent/query"),
    Body = iolist_to_binary(json:encode(#{<<"query">> => Query,
                                          <<"intent">> => ?INTENT})),
    case post(Url, Body) of
        {ok, Resp} ->
            case (try json:decode(Resp) catch _:_ -> #{} end) of
                #{<<"results">> := Results} when is_list(Results) ->
                    rewrite_cards(Results, base());
                _ -> []
            end;
        {error, _} -> []
    end.

%% @doc em_filter handle/2 contract (stateless).
-spec handle(binary(), term()) -> {binary(), term()}.
handle(Query, Memory) ->
    Result = iolist_to_binary(json:encode(query(Query))),
    {Result, Memory}.

%% Uniform mesh-egress rewrite (shared with the tiles/ndvi filters): turn any
%% host-relative velora path into an absolute URL under the public base. Info
%% cards carry no link fields today so this is a no-op, but keeps the three
%% filters identical and future-proofs any link velora may add.
base() ->
    iolist_to_binary(
        application:get_env(velora_raster_info_filter, tiles_base,
                            "https://velora.roques.me")).

rewrite_cards(Cards, Base) -> [rewrite_card(C, Base) || C <- Cards].

rewrite_card(Card, Base) when is_map(Card) ->
    C1 = lists:foldl(fun(K, Acc) -> abs_field(Acc, K, Base) end, Card,
                     [<<"poll">>, <<"tiles">>, <<"result_tiles">>]),
    case maps:get(<<"preview">>, C1, undefined) of
        P when is_map(P) -> C1#{<<"preview">> => abs_field(P, <<"tiles">>, Base)};
        _                -> C1
    end;
rewrite_card(Other, _Base) -> Other.

%% Prefix a leading-slash relative path with Base; leave absolute/missing as-is.
abs_field(Map, Key, Base) ->
    case maps:get(Key, Map, undefined) of
        <<"/", _/binary>> = Rel -> Map#{Key => <<Base/binary, Rel/binary>>};
        _                       -> Map
    end.

post(Url, Body) ->
    _ = application:ensure_all_started(inets),
    _ = application:ensure_all_started(ssl),
    Req = {Url, [{"accept", "application/json"}], "application/json", Body},
    case httpc:request(post, Req, [{timeout, 30000}], [{body_format, binary}]) of
        {ok, {{_, 200, _}, _H, RespBody}} -> {ok, RespBody};
        {ok, {{_, Code, _}, _H, _}}       -> {error, {http, Code}};
        {error, R}                        -> {error, R}
    end.
