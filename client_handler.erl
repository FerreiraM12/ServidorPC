-module(client_handler).
-export([start/1, handle_client/2, process_command/3]).

-import(account_manager, [create_account/2, validate_login/2]).
-import(movement, [move_forward/1, turn_left/1, turn_right/1]).

-record(player, {id, x, y, direction}).  

start(Port) ->
    init_ets_table(),
    {ok, ListenSocket} = gen_tcp:listen(Port, [{active, false}, {packet, 0}, {reuseaddr, true}]),
    loop(ListenSocket).

init_ets_table() ->
    case ets:info(client_sockets) of
        undefined -> ets:new(client_sockets, [named_table, set, public]);
        _ -> ok
    end.

loop(ListenSocket) ->
    {ok, Socket} = gen_tcp:accept(ListenSocket),
    spawn(fun() -> initialize_player(Socket) end),  % Initialize the player record here
    loop(ListenSocket).


initialize_player(Socket) -> 
    PlayerId = next_player_id(),
    NewPlayer = #player{id = PlayerId, x = 500, y = 500, direction = 0},
    ets:insert(client_sockets, {Socket, NewPlayer}),
    io:format("New client connected. Player ID: ~p~n", [NewPlayer#player.id]),  % Debug print
    handle_client(Socket, NewPlayer).

next_player_id() ->
    case ets:info(client_sockets) of
        undefined -> 1;
        _ -> ets:info(client_sockets, size) + 1
    end.

handle_client(Socket, Player) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
            io:format("Received data from client: ~p~n", [Data]),  % Debug print
            NewPlayer = process_command(Socket, Data, Player),
            send_updated_position(Socket, NewPlayer),
            handle_client(Socket, NewPlayer);
        {error, Reason} ->
            io:format("Error reading data from client: ~p~n", [Reason]),  % Debug print
            ets:delete(client_sockets, Socket),
            gen_tcp:send(Socket, "Erro: Não foi possível ler os dados\n"),
            gen_tcp:close(Socket)
    end.

process_command(Socket, NetData, Player) ->
    io:format("Processing command: ~p~n", [NetData]),  % Debug print
    [Command | Data] = string:split(NetData, " "),
    case Command of
        "login" -> 
            io:format("Handling login with Data: ~p~n", [Data]),
            [Username | Password] = string:split(hd(Data), " "),
            io:format("Trying login with: ~p~n", [Username]),  % Debug print
            io:format("Trying login with: ~p~n", [hd(Password)]),  % Debug print
            Result = account_manager:validate_login(Username, hd(Password)),
            case Result of
                {ok, _} ->
                    io:format("Login successful for: ~p~n", [Username]),  % Debug print
                    gen_tcp:send(Socket, "login_success\n");
                _ -> 
                    gen_tcp:send(Socket, "login_failed\n")
            end,
            Player;
        "new_account" ->
            [Username | Password] = string:split(hd(Data), " "),
            Result = account_manager:create_account(Username, hd(Password)),
            case Result of
                {ok, _} ->
                    io:format("Account created successfully for: ~p~n", [Username]),  % Debug print
                    gen_tcp:send(Socket, "login_success\n");
                _ -> 
                    gen_tcp:send(Socket, "login_failed\n")
            end,
            Player;
        "a" ->
            %% Turn the player left
            NewPlayer = movement:turn_left(Player),
            update_player(Socket, NewPlayer),
            NewPlayer;
        "d" ->
            %% Turn the player right
            NewPlayer = movement:turn_right(Player),
            update_player(Socket, NewPlayer),
            NewPlayer;
        "w" ->
            %% Move the player forward
            NewPlayer = movement:move_forward(Player),
            update_player(Socket, NewPlayer),
            NewPlayer;
        "q" ->
            gen_tcp:send(Socket, "Quitting game\n"),
            ets:delete(client_sockets, Socket),
            gen_tcp:close(Socket);
        _ ->
            gen_tcp:send(Socket, "Invalid command\n")
    end.

update_player(Socket, Player) ->
    ets:insert(client_sockets, {Socket, Player}).

send_updated_position(_, Player) ->
    %% Broadcast updated position to all clients
    UpdatedPosition = io_lib:format("player_coords ~p ~p ~p\n", [Player#player.id, Player#player.x, Player#player.y]),
    io:format("Broadcasting updated position: ~p~n", [UpdatedPosition]),  % Debug print
    AllClients = ets:tab2list(client_sockets),
    lists:foreach(fun({ClientSocket, _}) -> 
        gen_tcp:send(ClientSocket, UpdatedPosition)
    end, AllClients).