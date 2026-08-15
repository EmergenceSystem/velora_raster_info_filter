%%%-------------------------------------------------------------------
%%% @doc velora_raster_info_filter OTP application.
%%%
%%% A thin Emergence adapter: it advertises a raster metadata capability
%%% vector on the em_pop gossip mesh and, on POST /agent/query, forwards the
%%% query to a running velora node (the "eyes of Emergence") with intent
%%% "info". velora does the heavy GDAL/COG introspection work and returns
%%% info cards; this filter only relays them into the mesh.
%%%
%%% Configuration keys (application env):
%%%   pop_port   — em_pop gossip port      (default 9214)
%%%   query_port — Cowboy HTTP query port  (default 9215)
%%%   pop_seeds  — list of {Host, Port} seed peers (default [])
%%%   velora_url — velora /agent/query endpoint
%%%                (default "http://127.0.0.1:8080/agent/query")
%%% @end
%%%-------------------------------------------------------------------
-module(velora_raster_info_filter_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    case velora_raster_info_filter_sup:start_link() of
        {ok, Pid} ->
            ok = start_pop_and_http(),
            {ok, Pid};
        Error ->
            Error
    end.

stop(_State) ->
    catch cowboy:stop_listener(velora_raster_info_filter_query_listener),
    catch em_pop_sup:stop_node(velora_raster_info_filter),
    ok.

start_pop_and_http() ->
    PopPort   = application:get_env(velora_raster_info_filter, pop_port,   9214),
    QueryPort = application:get_env(velora_raster_info_filter, query_port, 9215),
    Seeds     = application:get_env(velora_raster_info_filter, pop_seeds,  []),
    Vec = em_filter_vec:from_capabilities(
              [<<"raster">>, <<"geotiff">>, <<"metadata">>, <<"gis">>,
               <<"cog">>, <<"bands">>, <<"projection">>, <<"geo">>]),
    catch em_pop_sup:stop_node(velora_raster_info_filter),
    catch cowboy:stop_listener(velora_raster_info_filter_query_listener),
    {ok, PopPid} = em_pop_sup:start_node(velora_raster_info_filter, #{
        port            => PopPort,
        query_port      => QueryPort,
        vector          => Vec,
        max_peers       => 100,
        gossip_interval => 5_000
    }),
    lists:foreach(
        fun({H, P}) -> catch em_pop_node:add_peer(PopPid, H, P) end,
        Seeds),
    Dispatch = cowboy_router:compile([
        {'_', [{"/agent/query", em_filter_http,
                #{server => velora_raster_info_filter_server}}]}
    ]),
    {ok, _} = cowboy:start_clear(velora_raster_info_filter_query_listener,
                                  [{port, QueryPort}],
                                  #{env => #{dispatch => Dispatch}}),
    logger:notice("[velora_raster_info_filter] gossip port ~w  query port ~w",
                  [PopPort, QueryPort]),
    ok.
