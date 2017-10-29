-module(rooster_dispatcher).

-export([match_route/2, compare_route_tokens/3, parse_route/1, handle_request/3]).

match_route(#{path := Path, method := Method} = Req, Routes) ->
  match_route(Path, Method, Req, Routes).

match_route(_, _, _Req, []) -> {404, #{message => <<"Not found">>}};
match_route(RequestedRoute, Method, Req, [{Method, Route, Fn, Middleware} | T]) ->
  RouteTokens = parse_route(Route),
  RequestedRouteTokens = parse_route(RequestedRoute),
  {IsValid, Params} = compare_route_tokens(RouteTokens, RequestedRouteTokens, #{}),
  if IsValid =:= true ->
    handle_request(Req#{params := Params}, Fn, Middleware);
    true ->
      match_route(RequestedRoute, Method, Req, T)
  end;
match_route(Route, M1, Req, [_ | T]) -> match_route(Route, M1, Req, T).

handle_request(Request, Fn, Middleware) ->
  Res = rooster_middleware:enter(Request, Middleware),
  call_route(Res, Fn, Middleware).

call_route({break, Resp}, _, _) -> rooster_adapter:route_response(Resp);
call_route({ok, Req}, Fn, Middleware)->
  RouteResponse = rooster_adapter:route_response(Fn(Req)),
  {_, Response} = rooster_middleware:leave(RouteResponse, Middleware),
  Response.

parse_route(Route) ->
  [RouteWithoutQueryParams | _] = string:tokens(Route, "?"),
  RouteTokens = string:tokens(RouteWithoutQueryParams, "/"),
  RouteTokens.

compare_route_tokens([], [], Acc) -> {true, Acc};
compare_route_tokens([], [_H | _T], _) -> {false, {}};
compare_route_tokens([_H | _T], [], _) -> {false, {}};
compare_route_tokens([H1 | T1], [H2 | T2], Acc) ->
  IsPathParam = string:str(H1, ":") =:= 1,
  SameToken = H1 =:= H2,
  if IsPathParam ->
    compare_route_tokens(T1, T2, new_param(Acc, {H1, H2}));
    SameToken ->
      compare_route_tokens(T1, T2, Acc);
    true ->
      {false, {}}
  end.

new_param(Params, {Key, Value}) ->
  Params#{erlang:list_to_atom(string:slice(Key, 1)) => Value}.
