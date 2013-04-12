restclient(0.2.0) An erlang REST Client library
====================================

## DESCRIPTION

restclient is a library to help with consuming RESTful web services. It supports encoding and decoding JSON, Percent and XML and comes with a convinencien function for working with urls and query parameters.

## USAGE

Include restclient as a rebar dependency with:

	{deps, [{restc, ".*", {git, "git://github.com/kivra/restclient.git", {tag, "0.2.0"}}}]}.

You have to start inets before using the client and if you want to use https make sure to start ssl before.
Then you can use the client as:

```erlang

	Erlang R15B (erts-5.9) [source] [64-bit] [smp:8:8] [async-threads:0] [hipe] [kernel-poll:false]

	Eshell V5.9  (abort with ^G)
	1> application:start(inets).
	ok
	2> application:start(crypto).
	ok
	3> application:start(public_key).
	ok
	4> application:start(ssl).
	ok
	5> {ok, Req} = restc:request(get, <<"https://api.github.com">>).
	{ok,{req,{client, [...]}}}
	6> restc:body(Req).
	{ok,<<"Body">>, {req,{client, [...]}}}

```
