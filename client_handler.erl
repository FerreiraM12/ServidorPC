-module(client_handler).
-export([start/1, handle_client/1]).

-import(account_manager, [process_request/0]).

start(Port) ->
    {ok, ListenSocket} = gen_tcp:listen(Port, [{active, false}, {packet, 0}, {reuseaddr, true}]),
    loop(ListenSocket).

loop(ListenSocket) ->
    {ok, Socket} = gen_tcp:accept(ListenSocket),
    spawn(fun() -> handle_client(Socket) end),
    loop(ListenSocket).

handle_client(Socket) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
            process_request(Socket, Data);
        {error, _} ->
            gen_tcp:send(Socket, "Erro: Não foi possível ler os dados\n"),
            gen_tcp:close(Socket)
    end.

process_request(Socket, Data) ->
    Response = account_manager:process_request(Data),
    gen_tcp:send(Socket, Response),
    gen_tcp:close(Socket).