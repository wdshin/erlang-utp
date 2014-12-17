%%% @author Jesper Louis andersen <jesper.louis.andersen@gmail.com>
%%% @copyright (C) 2011, Jesper Louis andersen
%%% @doc uTP protocol decoder process
%%% @end
-module(gen_utp_decoder).

-behaviour(gen_server).

-include("utp.hrl").

%% API
-export([start_link/0]).
-export([decode_and_dispatch/3]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-record(state, {}).

%%%===================================================================

%% @doc Starts the server
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

decode_and_dispatch(Packet, IP, Port) ->

    io:format("~p ~p decode_and_dispatch ~p ~n",[?MODULE,?LINE,{Packet,IP,Port}]),
    gen_server:cast(?SERVER, {packet, Packet, IP, Port}).

%%%===================================================================

%% @private
%% @end
init([]) ->
    {ok, #state{}}.

%% @private
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%% @private
handle_cast({packet, P, Addr, Port}, S) ->
    case utp_proto:decode(P) of
        {ok, 
         {#packet { conn_id = CID,
                    ty = PTy } = Packet, TS, TSDiff, RecvTime}} ->
            case PTy of
                st_reset ->
                    io:format("~p ~p packet st_reset ~p ~n",[?MODULE,?LINE,{CID,PTy,Packet, TS, TSDiff, RecvTime}]),

                    case gen_utp:lookup_registrar(CID, Addr, Port) of
                        {ok, Pid} ->
                            gen_utp_worker:incoming(Pid, Packet, {TS, TSDiff, RecvTime});
                        not_found ->
                            case gen_utp:lookup_registrar(CID+1, Addr, Port) of
                                {ok, Pid} ->
                                    gen_utp_worker:incoming(Pid, Packet, {TS, TSDiff, RecvTime});
                                not_found ->
                                    gen_utp:incoming_unknown(Packet, Addr, Port)
                            end
                    end;
                _OtherState ->
                    io:format("~p ~p packet other state ~p ~n",[?MODULE,?LINE,{CID,PTy,Packet, TS, TSDiff, RecvTime}]),
                    Ret=gen_utp:lookup_registrar(CID, Addr, Port),
                    %%case gen_utp:lookup_registrar(CID, Addr, Port) of
                    io:format("~p ~p packet other state gen_utp:lookup_registrar ~p ~n",[?MODULE,?LINE,Ret]),
                    case Ret of
                        {ok, Pid} ->
                            gen_utp_worker:incoming(Pid, Packet, {TS, TSDiff, RecvTime});
                        not_found ->
                            

                            gen_utp:incoming_unknown(Packet, Addr, Port)
                    end
            end,
            {noreply, S};
        {error, Reason} ->
            error_logger:info_report([decoder_error, Reason]),
            {noreply, S}
    end;
handle_cast(_Msg, State) ->
    {noreply, State}.

%% @private
handle_info(_Info, State) ->
    {noreply, State}.

%% @private
terminate(_Reason, _State) ->
    ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
