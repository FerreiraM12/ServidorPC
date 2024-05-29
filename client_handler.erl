-module(client_handler).
-export([start/1, game_session_handler/2, handle_client/1, process_command/2, enqueue_player/1, start_game/1, handle_login/2, handle_create_account/2]).
-import(account_manager, [create_account/2, validate_login/2]).
-import(movement, [move_forward/1, turn_left/1, turn_right/1]).

-define(MAX_PLAYERS_PER_GAME, 4).

-record(player, {id, socket, x, y, direction, level = 1, locked = false, consecutive_wins = 0, consecutive_losses = 0, gamePid = 0}).
-record(planet, {id, positionX, positionY}).

%% Entry point to start the server listening on a specified port.
start(Port) ->
    init_ets_queue(),
    {ok, ListenSocket} = gen_tcp:listen(Port, [{active, false}, {packet, 0}, {reuseaddr, true}]),
    io:format("Server started, listening on port ~p~n", [Port]),
    accept_connections(ListenSocket).
    %loop(ListenSocket).

init_ets_queue() ->
    ets:new(player_queue, [named_table, set, public, {keypos, 1}]).

accept_connections(ListenSocket) ->
    spawn(fun() -> loop(ListenSocket) end).

loop(ListenSocket) ->
    {ok, Socket} = gen_tcp:accept(ListenSocket),
    spawn(fun() -> handle_connection(Socket) end),
    loop(ListenSocket).

handle_connection(Socket) ->
    NewPlayer = initialize_player(Socket),
    handle_client(NewPlayer).

initialize_player(Socket) ->
    NewPlayer = #player{id = erlang:unique_integer() rem 500, socket = Socket, x = 500, y = 500, direction = 0},
    io:format("New client connected. Player ID: ~p~n", [NewPlayer#player.id]),
    NewPlayer.

%% Handles incoming data from the client.
handle_client(Player) ->
    case gen_tcp:recv(Player#player.socket, 0) of
        {ok, Data} ->
            io:format("Received data from player ~p: ~p~n", [Player#player.id, Data]),
            UpdatedPlayer = process_command(Data, Player),
            handle_client(UpdatedPlayer); % Recursively handle the next command with updated player
        {error, Reason} ->
            io:format("Client disconnected: ~p~n", [Reason]),
            ets:delete(player_queue, Player#player.id),
            gen_tcp:close(Player#player.socket)
    end.

%% Processes commands received from the client.
process_command(Data, Player) ->
    CommandList = string:split(Data, " ", all),
    Command = hd(CommandList),
    %io:format("Processing command ~p from player ~p~n", [Command, Player#player.id]),
    case Command of
        "login" ->
            handle_login(CommandList, Player);
        "new_account" ->
            handle_create_account(CommandList, Player);
        "a" ->
            NewPlayer = movement:turn_left(Player),
            Player#player.gamePid ! {update, NewPlayer},
            NewPlayer;
        "d" ->
            NewPlayer = movement:turn_right(Player),
            Player#player.gamePid ! {update, NewPlayer},
            NewPlayer;
        "w" ->
            NewPlayer = movement:move_forward(Player),
            Player#player.gamePid ! {update, NewPlayer},
            NewPlayer;
        "q" ->
            gen_tcp:send(Player#player.socket, "Quitting game\n"),
            ets:delete(player_queue, Player#player.id),
            gen_tcp:close(Player#player.socket),
            Player; % Ensure to return the modified player or a flag to stop further processing
        "gamePid" ->
            io:format("Received game PID from player ~p~n", [Player#player.id]),
            NewPlayer = Player#player{gamePid = list_to_pid(hd(tl(CommandList)))},
            io:format("Player ~p~n: ", [NewPlayer]),
            list_to_pid(hd(tl(CommandList))) ! ola,
            NewPlayer;
        _ ->
            gen_tcp:send(Player#player.socket, "Invalid command\n"),
            Player
    end.

%% Handles login functionality.
handle_login([_, Username, Password], Player) ->
    case account_manager:validate_login(Username, Password) of
        {ok, Level} ->
            UpdatedPlayer = Player#player{level = Level, locked = true},
            gen_tcp:send(Player#player.socket, "login_success\n"),
            io:format("Login successful for ~p~n", [Username]),
            enqueue_player(UpdatedPlayer),
            UpdatedPlayer;
        {error, _} ->
            io:format("Login failed for ~p~n", [Username]),
            gen_tcp:send(Player#player.socket, "Login failed\n"),
            Player
    end.

%% Handles account creation functionality.
handle_create_account([_, Username, Password], Player) ->
    io:format("Handling account creation for ~p~n", [Username]),
    case account_manager:create_account(Username, Password) of
        {ok, _} ->
            gen_tcp:send(Player#player.socket, "Account created successfully\n"),
            io:format("Account created for ~p~n", [Username]),
            Player;
        _ ->
            gen_tcp:send(Player#player.socket, "Account creation failed\n"),
            io:format("Account creation failed for ~p~n", [Username]),
            Player
    end.

%% Enqueues the player in the global queue
enqueue_player(Player) ->
    io:format("Enqueuing player ~p~n", [Player#player.id]),
    ets:insert(player_queue, {Player#player.id, Player}),
    matchmaking:try_matchmaking().

%% Starts a new game session with the given players.
start_game(Players) ->
    % create a list with 3 planets
    Planets = [{planet, 1, 100, 100}, {planet, 2, 200, 200}, {planet, 3, 300, 300}],
    GamePid = spawn_link(fun() -> game_session_handler(Players, Planets) end),
    lists:foreach(fun(P) -> gen_tcp:send(P#player.socket, io_lib:format("Game_started ~p\n", [GamePid])) end, Players),

    io:format("Game session started with PID ~p~n", [GamePid]).

game_session_handler(Players, Planets) ->
    loop_update(Players, Planets, 0).

%% Recursively updates game state and sends position updates to all players.
loop_update(Players, Planets, I) ->
    receive
        {update, Player} -> 
            NewPlayers = lists:map(fun(P) ->
            case P#player.id == Player#player.id of
                true -> Player;
                false -> P
            end
        end, Players)
        after 0 -> NewPlayers = Players
    end,
    broadcast_positions(Players),
    if I rem 10 == 0 ->
        NewPlanets = update_planets_positions(Planets, 20),
        broadcast_planets_positions(Players, NewPlanets);
    true -> NewPlanets = Planets
    end,
    timer:sleep(50),  % Sleep for 50 milliseconds before the next update
    loop_update(NewPlayers, NewPlanets, (I + 1) rem 10).

broadcast_planets_positions(Players, Planets) ->
    Positions = lists:map(fun(P) -> {P#planet.id, P#planet.positionX, P#planet.positionY} end, Planets),
    lists:foreach(fun(P) ->
        PositionData = lists:map(fun({Id, X, Y}) ->
            io_lib:format("planet_pos ~p ~p ~p~n", [Id, X, Y])
        end, Positions),
        
        gen_tcp:send(P#player.socket, string:join(PositionData, ""))
    end, Players).

update_planets_positions(Planets, AngleIncrement) ->
    lists:map(fun(P) ->
        Radius = math:sqrt((P#planet.positionX - 500) * (P#planet.positionX - 500) + (P#planet.positionY - 400) * (P#planet.positionY - 400)),
        CurrentAngle = (math:atan2(P#planet.positionY-400, P#planet.positionX-500) * 360) / (2 * math:pi()),
        NewX = Radius * math:cos(2 * math:pi() * (CurrentAngle + AngleIncrement) / 360) + 500,
        NewY = Radius * math:sin(2 * math:pi() * (CurrentAngle + AngleIncrement) / 360) + 400,
        io:format("Planet ~p: ~p, ~p -> ~p, ~p~n", [P#planet.id, P#planet.positionX, P#planet.positionY, NewX, NewY]),
        P#planet{positionX = NewX, positionY = NewY}
    end, Planets).

%% Broadcasts the current position of each player to all players.
broadcast_positions(Players) ->
    Positions = lists:map(fun(P) -> {P#player.id, P#player.x, P#player.y, P#player.direction} end, Players),
    lists:foreach(fun(P) ->
        PositionData = lists:map(fun({Id, X, Y, Dir}) ->
            io_lib:format("player_pos ~p ~p ~p ~p\n", [Id, X, Y, Dir])
        end, Positions),
        gen_tcp:send(P#player.socket, string:join(PositionData, ""))
    end, Players).

%% Update player level
update_player_level(Player, Outcome) ->
    NewWins = case Outcome of
        win -> Player#player.consecutive_wins + 1;
        lose -> 0
    end,
    NewLosses = case Outcome of
        lose -> Player#player.consecutive_losses + 1;
        win -> 0
    end,
    {NewLevel, ResetWins, ResetLosses} = case {NewWins, NewLosses} of
        {Wins, _} when Wins >= Player#player.level -> {Player#player.level + 1, 0, Player#player.consecutive_losses};
        {_, Losses} when Losses >= trunc(Player#player.level / 2) -> {max(Player#player.level - 1, 1), Player#player.consecutive_wins, 0};
        _ -> {Player#player.level, NewWins, NewLosses}
    end,
    Player#player{level = NewLevel, consecutive_wins = ResetWins, consecutive_losses = ResetLosses}.