-module(vector_math).
-export([vector_add/2, vector_subtract/2, vector_dot/2, vector_scale/2, vector_magnitude/1, vector_normalize/1, squared_magnitude/1]).

% Add two vectors. This operation adds the corresponding components of the two vectors
vector_add({X1, Y1}, {X2, Y2}) ->
    {X1 + X2, Y1 + Y2}.

% Subtract two vectors. This operation subtracts the corresponding components of the two vectors
vector_subtract({X1, Y1}, {X2, Y2}) ->
    {X1 - X2, Y1 - Y2}.

% Calculate the dot product of two vectors. The dot product is the sum of the products of the corresponding components of the two vectors
vector_dot({X1, Y1}, {X2, Y2}) ->
    X1 * X2 + Y1 * Y2.

% Scale a vector by a scalar value. This operation multiplies each component of the vector by the scalar value
vector_scale({X, Y}, Scalar) ->
    {X * Scalar, Y * Scalar}.

% Calculate the magnitude of a vector. In simple terms, the length of the vector
vector_magnitude({X, Y}) ->
    math:sqrt(X * X + Y * Y).

% Normalize a vector. Returns a vector with the same direction but with magnitude 1
vector_normalize({X, Y}) ->
    Magnitude = vector_magnitude({X, Y}),
    {X / Magnitude, Y / Magnitude}.

squared_magnitude({X, Y}) ->
    X * X + Y * Y.