-module(client_handler).
-export([start/1, handle_client/2]).

-import(account_manager, [process_request/0]).
-import(movement, [move_forward/1, turn_left/1, turn_right/1]).

-record(player, {id, x, y, direction}).  

start(Port) ->
    {ok, ListenSocket} = gen_tcp:listen(Port, [{active, false}, {packet, 0}, {reuseaddr, true}]),
    loop(ListenSocket).

loop(ListenSocket) ->
    {ok, Socket} = gen_tcp:accept(ListenSocket),
    spawn(fun() -> initialize_player(Socket) end),  % Initialize the player record here
    loop(ListenSocket).


initialize_player(Socket) -> 
    NewPlayer = #player{id = 1, x = 0, y = 0, direction = 0},
    io:format("New client connected. Player ID: ~p~n", [NewPlayer#player.id]),  % Debug print
    handle_client(Socket, NewPlayer).

handle_client(Socket, Player) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
            io:format("Received data from client: ~p~n", [Data]),  % Debug print
            NewPlayer = process_command(Socket, Data, Player),
            send_updated_position(Socket, NewPlayer),
            handle_client(Socket, NewPlayer);
        {error, Reason} ->
            io:format("Error reading data from client: ~p~n", [Reason]),  % Debug print
            gen_tcp:send(Socket, "Erro: Não foi possível ler os dados\n"),
            gen_tcp:close(Socket)
    end.

process_command(Socket, Command, Player) ->
    io:format("Processing command: ~p~n", [Command]),  % Debug print
    case Command of
        "a" ->
            %% Turn the player left
            NewPlayer = movement:turn_left(Player),
            NewPlayer;
        "d" ->
            %% Turn the player right
            NewPlayer = movement:turn_right(Player),
            NewPlayer;
        "w" ->
            %% Move the player forward
            NewPlayer = movement:move_forward(Player),
            NewPlayer;
        "q" ->
            gen_tcp:send(Socket, "Quitting game\n"),
            gen_tcp:close(Socket);
        _ ->
            gen_tcp:send(Socket, "Invalid command\n")
    end.

send_updated_position(Socket, Player) ->
    %% Send updated position to the client
    io:format("updated position: ~p,~p,~p", [Player#player.x, Player#player.y, Player#player.direction]),  % Debug print
    UpdatedPosition = io_lib:format("~p,~p\n", [Player#player.x, Player#player.y]),
    gen_tcp:send(Socket, UpdatedPosition).


