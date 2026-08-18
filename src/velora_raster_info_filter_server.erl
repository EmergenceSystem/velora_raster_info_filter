%%%-------------------------------------------------------------------
%%% @doc velora_raster_info_filter gen_server. Registered as
%%% `velora_raster_info_filter_server'. Handles HTTP query requests from
%%% em_filter_http by delegating to velora_raster_info_filter_handler:query/1.
%%% @end
%%%-------------------------------------------------------------------
-module(velora_raster_info_filter_server).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, undefined}.

handle_call({http_query, Query}, From, State) ->
    % Non-blocking: run the forward in a worker, reply async, so queries run
    % concurrently (an inline blocking forward stalls all others under load).
    _ = spawn(fun() ->
        Reply = try
            Items = velora_raster_info_filter_handler:query(Query),
            {ok, iolist_to_binary(json:encode(Items))}
        catch E:R ->
            logger:error("[velora_raster_info_filter] handler error ~p:~p", [E, R]),
            {error, handler_failed}
        end,
        gen_server:reply(From, Reply)
    end),
    {noreply, State};
handle_call(_Req, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
