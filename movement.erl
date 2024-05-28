%% movement.erl
-module(movement).
-compile({no_auto_import,[floor/1]}).

-import(math, [cos/1, sin/1]).


-export([move_forward/1, turn_left/1, turn_right/1]).

-record(player, {id, socket, x, y, direction, level = 1, locked = false, consecutive_wins = 0, consecutive_losses = 0, gamePid = 0}).

to_radians(Degrees) ->
    Degrees * math:pi() / 180.

%% Move the player forward in the direction they are facing
move_forward(Player) ->
  XDelta = math:cos(to_radians(math:floor(Player#player.direction))),
  YDelta = math:sin(to_radians(math:floor(Player#player.direction))),
  NewX = Player#player.x + XDelta * 10,
  NewY = Player#player.y + YDelta * 10,
  Player#player{x = NewX, y = NewY}.

%% Turn the player to the left
turn_left(Player) ->
  NewDirection = (Player#player.direction - 90 + 360) rem 360,  % Handle negative values
  Player#player{direction = NewDirection}.

turn_right(Player) ->
  NewDirection = (Player#player.direction + 90) rem 360,
  Player#player{direction = NewDirection}.