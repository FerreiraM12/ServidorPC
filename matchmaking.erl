-module(matchmaking).
-export([enqueue_player/1, try_matchmaking/0, ready_to_play/1]).

-define(MAX_PLAYERS_PER_GAME, 2).
-record(player, {id, socket, x, y, direction, level = 1, locked = false, consecutive_wins = 0, consecutive_losses = 0, gamePid = 0}).

% Enqueue player and check if a game can be started
enqueue_player(Player) ->
    io:format("Enqueuing player ~p~n", [Player#player.id]),
    ets:insert(player_queue, {Player#player.id, Player}),
    try_matchmaking().

% Try to start a game if conditions are met
try_matchmaking() ->
    Players = ets:tab2list(player_queue),
    io:format("Trying matchmaking with players: ~p~n", [Players]),
    case can_start_game(Players) of
        {true, SelectedPlayers} ->
            io:format("Match found. Starting game with players: ~p~n", [SelectedPlayers]),
            start_game(SelectedPlayers),
            lists:foreach(fun(Player) -> ets:delete(player_queue, Player#player.id) end, SelectedPlayers);
        false ->
            io:format("No match found.~n"),
            ok
    end.

% Check conditions and start game
can_start_game(Players) ->
    GroupedPlayers = group_players_by_level(Players),
    case find_valid_group(GroupedPlayers) of
        {ok, ValidGroup} ->
            {true, ValidGroup};
        error ->
            false
    end.

    % Filter and group players by level
    %{ReadyPlayers, RemainingQueue} = lists:partition(fun(P) -> ready_to_play(P) end, Players),
    %io:format("Ready players: ~p~n", [ReadyPlayers]),
    %case length(ReadyPlayers) >= ?MAX_PLAYERS_PER_GAME of
    %    true ->
    %        io:format("Enough players ready for a game.~n"),
    %        {true, lists:sublist(ReadyPlayers, ?MAX_PLAYERS_PER_GAME)};
    %    false ->
    %        io:format("Not enough players ready for a game.~n"),
    %        false
    %end.


% Group players by level
group_players_by_level(Players) ->
    io:format("Grouping players ~p~n", [Players]),

    lists:foldl(fun({_, Player}, Acc) ->
        Level = Player#player.level,
        io:format("Grouping player ~p at level ~p~p~n", [Player#player.id, Level, Acc]),
        case lists:keyfind(Level, 1, Acc) of
            false ->
                [{Level, [Player]} | Acc];
            {Level, List} ->
                lists:keyreplace(Level, 1, Acc, {Level, List ++ [Player]})
        end
    end, [], Players).

% Find a valid group of players within one level difference
find_valid_group(GroupedPlayers) ->
    lists:foldl(fun({Level, PlayersAtLevel}, Acc) ->
        case length(PlayersAtLevel) of
            N when N >= ?MAX_PLAYERS_PER_GAME ->
                {ok, lists:sublist(PlayersAtLevel, ?MAX_PLAYERS_PER_GAME)};
            _ ->
                case try_find_additional_players(Level, PlayersAtLevel, GroupedPlayers) of
                    {ok, ValidGroup} ->
                        {ok, ValidGroup};
                    error ->
                        Acc
                end
        end
    end, error, GroupedPlayers).

% Try to find additional players to form a valid group
try_find_additional_players(Level, PlayersAtLevel, GroupedPlayers) ->
    AboveLevel = Level + 1,
    BelowLevel = Level - 1,
    PotentialPlayers = PlayersAtLevel ++ get_players_from_level(AboveLevel, GroupedPlayers) ++ get_players_from_level(BelowLevel, GroupedPlayers),
    ValidGroup = lists:sublist(PotentialPlayers, ?MAX_PLAYERS_PER_GAME),
    if length(ValidGroup) == ?MAX_PLAYERS_PER_GAME -> {ok, ValidGroup}; true -> error end.

get_players_from_level(Level, GroupedPlayers) ->
    case lists:keyfind(Level, 1, GroupedPlayers) of
        false -> [];
        {_, Players} -> Players
    end.

% Define ready_to_play considering level and availability
ready_to_play(Player) ->
    % Implementation based on level difference and player availability
    true.  % Simplified for illustration

% Start game with the selected players
start_game(Players) ->
    io:format("Starting game with players: ~p~n", [Players]),
    %lists:foreach(fun(P) -> 
        %gen_tcp:send(P#player.socket, "game_started\n")
        %ets:insert(player_queue, {P#player.id, P}) % Update player status in ETS
    %end, Players),
    client_handler:start_game(Players).