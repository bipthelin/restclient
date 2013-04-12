%% ----------------------------------------------------------------------------
%%
%% restc: Erlang Rest Client
%%
%% Copyright (c) 2012-2013 KIVRA
%%
%% Permission is hereby granted, free of charge, to any person obtaining a
%% copy of this software and associated documentation files (the "Software"),
%% to deal in the Software without restriction, including without limitation
%% the rights to use, copy, modify, merge, publish, distribute, sublicense,
%% and/or sell copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
%% DEALINGS IN THE SOFTWARE.
%%
%% ----------------------------------------------------------------------------

-module(restc).

-export([request/1]).
-export([request/2]).
-export([request/3]).
-export([request/4]).
-export([request/5]).
-export([request/6]).

-export([body/1]).

-record(req, {
                client,
                status      :: status_code(),
                headers     :: headers()
             }).

-type method()       :: binary | head | get | put | post | trace | options |
                        delete | patch.
-type url()          :: binary | string().
-type headers()      :: [header()].
-type header()       :: {binary(), binary()}.
-type status_codes() :: [status_code()].
-type status_code()  :: integer().
-type reason()       :: term().
-type content_type() :: json | xml | percent.
-type property()     :: atom() | tuple().
-type proplist()     :: [property()].
-type body()         :: binary() | proplist().
-type response()     :: {ok, #req{}} | {error, Reason::reason()}.

-define(DEFAULT_ENCODING, json).
-define(DEFAULT_CTYPE, <<"application/json">>).


%%% API ========================================================================


%% @equiv request(get, ?DEFAULT_ENCODING, Url, [], [], [])
-spec request(Url) -> Response when
    Url      :: url(),
    Response :: response().
request(Url) ->
    request(get, ?DEFAULT_ENCODING, Url, [], [], []).

%% @equiv request(Method, ?DEFAULT_ENCODING, Url, [], [], [])
-spec request(Method, Url) -> Response when
    Method   :: method(),
    Url      :: url(),
    Response :: response().
request(Method, Url) ->
    request(Method, ?DEFAULT_ENCODING, Url, [], [], []).

%% @equiv request(Method, ?DEFAULT_ENCODING, Url, Expect, [], [])
-spec request(Method, Url, Expect) -> Response when
    Method   :: method(),
    Url      :: url(),
    Expect   :: status_codes(),
    Response :: response().
request(Method, Url, Expect) ->
    request(Method, ?DEFAULT_ENCODING, Url, Expect, [], []).

%% @equiv request(Method, Type, Url, Expect, [], [])
-spec request(Method, Type, Url, Expect) -> Response when
    Method   :: method(),
    Type     :: content_type(),
    Url      :: url(),
    Expect   :: status_codes(),
    Response :: response().
request(Method, Type, Url, Expect) ->
    request(Method, Type, Url, Expect, [], []).

%% @equiv request(Method, Type, Url, Expect, Headers, [])
-spec request(Method, Type, Url, Expect, Headers) -> Response when
    Method   :: method(),
    Type     :: content_type(),
    Url      :: url(),
    Expect   :: status_codes(),
    Headers  :: headers(),
    Response :: response().
request(Method, Type, Url, Expect, Headers) ->
    request(Method, Type, Url, Expect, Headers, []).

%% @doc Perform a request and parse any incoming and/or outgoing payload
%%      using the given content type.
-spec request(Method, Type, Url, Expect, Headers, Body) -> Response when
    Method   :: method(),
    Type     :: content_type(),
    Url      :: url(),
    Expect   :: status_codes(),
    Headers  :: headers(),
    Body     :: body(),
    Response :: response().
request(Method, Type, Url, Expect, Headers0, Body) ->
    Headers1 = augment_headers(Type, Headers0),
    Response = parse_response(do_request(Method, Type, Url, Headers1, Body)),
    case Response of
        #req{status = Status} ->
            case check_expect(Status, Expect) of
                true  -> {ok, Response};
                false -> {error, Response}
            end;
        Error ->
            Error
    end.

-spec body(Req :: #req{}) -> {ok, binary(), #req{}} | {error, atom()}.
body(#req{client = Client, headers = Headers} = Req) ->
    Type = proplists:get_value(<<"Content-Type">>, Headers, ?DEFAULT_CTYPE),
    Type2 = parse_type(Type),
    case hackney:body(Client) of
        {ok, Body, Client2} ->
            {ok, parse_body(Type2, Body), Req#req{client = Client2}};
        Error               -> Error
    end.


%%% INTERNAL ===================================================================


augment_headers(Type, Headers0) ->
    Headers1 = lists:delete(<<"Accept">>, Headers0),
    Headers2 = lists:delete(<<"Content-Type">>, Headers1),
    [{<<"Accept">>, <<(get_accesstype(Type))/binary, ", */*;q=0.9">>},
     {<<"Content-Type">>, get_ctype(Type)} | Headers2].

do_request(post, Type, Url, Headers, Body) ->
    Body2 = encode_body(Type, Body),
    hackney:request(post, Url, Headers, Body2);
do_request(put, Type, Url, Headers, Body) ->
    Body2 = encode_body(Type, Body),
    hackney:request(put, Url, Headers, Body2);
do_request(Method, _, Url, Headers, _) ->
    hackney:request(Method, Url, Headers).

check_expect(_Status, []) ->
    true;
check_expect(Status, Expect) ->
    lists:member(Status, Expect).

encode_body(json, Body) ->
    jsx:encode(Body);
encode_body(percent, Body) ->
    mochiweb_util:urlencode(Body);
encode_body(xml, Body) ->
    lists:flatten(xmerl:export_simple(Body, xmerl_xml));
encode_body(_, Body) ->
   encode_body(?DEFAULT_ENCODING, Body).

parse_response({ok, Status, Headers, Client}) ->
    #req{status = Status, headers = Headers, client = Client};
parse_response({error, Type}) ->
    {error, Type}.

parse_type(Type) ->
    case binary:split(Type, <<";">>) of
        [CType, _] -> CType;
        _ -> Type
    end.

parse_body([], Body)                     -> Body;
parse_body(_, [])                        -> [];
parse_body(_, <<>>)                      -> [];
parse_body(<<"application/json">>, Body) -> jsx:decode(Body);
parse_body(<<"application/xml">>, Body)  ->
    {ok, Data, _} = erlsom:simple_form(binary_to_list(Body)),
    Data;
parse_body(<<"text/xml">>, Body)         ->
    parse_body(<<"application/xml">>, Body);
parse_body(_, Body)                      -> Body.

get_accesstype(json)    -> <<"application/json">>;
get_accesstype(xml)     -> <<"application/xml">>;
get_accesstype(percent) -> <<"application/json">>;
get_accesstype(_)       -> get_ctype(?DEFAULT_ENCODING).

get_ctype(json)    -> <<"application/json">>;
get_ctype(xml)     -> <<"application/xml">>;
get_ctype(percent) -> <<"application/x-www-form-urlencoded">>;
get_ctype(_)       -> get_ctype(?DEFAULT_ENCODING).
