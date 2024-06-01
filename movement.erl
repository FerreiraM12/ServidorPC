%% movement.erl
-module(movement).
-compile({no_auto_import,[floor/1]}).

-import(math, [cos/1, sin/1]).


-export([move_forward/1, turn_left/1, turn_right/1]).

-record(player, {id, socket, x, y, direction, velocity = {0,0}, level = 1, locked = false, consecutive_wins = 0, consecutive_losses = 0, gamePid = 0}).

to_radians(Degrees) ->
    Degrees * math:pi() / 180.

%% Move the player forward in the direction they are facing

move_forward(Player) ->
  {Vx, Vy} = Player#player.velocity,
  NNewx = Vx + 1,
  NNewy = Vy + 1,
  XDelta = math:cos(to_radians(Player#player.direction))*NNewx,
  YDelta = math:sin(to_radians(Player#player.direction))*NNewy,
  NewVelocity = {NNewx, NNewy},
  %% Update position based on new velocity
  NewX = Player#player.x + XDelta,
  NewY = Player#player.y + YDelta,
  io:format("Moving player ~p to ~p, ~p with velocity ~p~n", [Player#player.id, NewX, NewY, NewVelocity]),
  Player#player{velocity = NewVelocity, x = NewX, y = NewY}.


%% Turn the player to the left
turn_left(Player) ->
  NewDirection = (Player#player.direction - 15 + 360) rem 360,  % Handle negative values
  Player#player{direction = NewDirection}.

turn_right(Player) ->
  NewDirection = (Player#player.direction + 15) rem 360,
  Player#player{direction = NewDirection}.
