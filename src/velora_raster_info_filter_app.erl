%%%-------------------------------------------------------------------
%%% @doc velora_raster_info_filter boot (application + supervisor).
%%%
%%% A thin Emergence adapter: registers a raster-metadata agent on the em_filter
%%% mesh and forwards each query to a running velora node with intent "info".
%%% velora does the GDAL/COG introspection and returns info cards; this filter
%%% relays them (rewriting velora's host-relative URLs to absolute).
%%%
%%% Follows the current em_filter agent model (em_filter:start_agent/3): the
%%% framework owns the em_disco WebSocket connection, JWT auth and em_pop node;
%%% the handler module supplies handle/2 + base_capabilities/0.
%%% @end
%%%-------------------------------------------------------------------
-module(velora_raster_info_filter_app).
-behaviour(application).
-behaviour(supervisor).

-export([start/2, stop/1, init/1]).

start(_Type, _Args) ->
    {ok, Pid} = supervisor:start_link({local, velora_raster_info_filter_boot_sup},
                                      ?MODULE, []),
    _ = application:ensure_all_started(em_filter),
    _ = em_filter:start_agent(velora_raster_info_filter,
                              velora_raster_info_filter_handler,
          #{pop_port     => 9214,
            query_port   => 9215,
            capabilities => velora_raster_info_filter_handler:base_capabilities(),
            pop_peers    => [{"localhost", 9101}],
            pop_role     => leaf}),
    {ok, Pid}.

stop(_State) -> ok.

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 1, period => 5}, []}}.
