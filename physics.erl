-module(physics).
-export([update_velocity/3, update_position/2, simulate/3, main/0]).
-record(body, {name, mass, position, velocity}).

-define(G, 6.67430e-11).

update_velocity(StaticBody, Body, TimeStep) ->
    SqrDst = vector_math:squared_magnitude(vector_math:vector_subtract(Body#body.position, StaticBody#body.position)),
    ForceDir = vector_math:vector_normalize(vector_math:vector_subtract(Body#body.position, StaticBody#body.position)),
    Force = vector_math:vector_scale(ForceDir, ?G * StaticBody#body.mass / SqrDst),
    Acceleration = vector_math:vector_scale(Force, 1 / Body#body.mass),
    NewVelocity = vector_math:vector_add(Body#body.velocity, vector_math:vector_scale(Acceleration, TimeStep)),
    Body#body{velocity = NewVelocity}.

update_position(Body, TimeStep) ->
    NewPosition = vector_math:vector_add(Body#body.position, vector_math:vector_scale(Body#body.velocity, TimeStep)),
    Body#body{position = NewPosition}.

simulate(Sun, Earth, Iterations) ->
    simulate(Sun, Earth, Iterations, 1).

simulate(_Sun, Earth, 0, _TimeStep) ->
    Earth;
simulate(Sun, Earth, Iterations, TimeStep) ->
    EarthAfterVelocityUpdate = update_velocity(Sun, Earth, TimeStep),
    EarthAfterPositionUpdate = update_position(EarthAfterVelocityUpdate, TimeStep),
    simulate(Sun, EarthAfterPositionUpdate, Iterations - 1, TimeStep),
    % state
    io:format("Earth's final velocity: ~p~n", [EarthAfterPositionUpdate#body.velocity]),
    io:format("Earth's final position: ~p~n", [EarthAfterPositionUpdate#body.position]).

main() ->
    Sun = #body{name="Sun", mass=1.989e30, position={0.0, 0.0}, velocity={0.0, 0.0}},
    Earth = #body{name="Earth", mass=5.972e24, position={1.0, 1.0}, velocity={0.0, 29783.0}},
    Iterations = 10000, % Number of iterations to simulate
    simulate(Sun, Earth, Iterations).