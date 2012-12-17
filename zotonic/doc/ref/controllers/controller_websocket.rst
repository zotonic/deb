
.. include:: meta-websocket.rst

Controller which opens a WebSocket connection to the browser.

The controller provides persistent WebSocket connections between the
client and the server. The default implementation is used by :ref:`mod_base`
when the :ref:`{% stream %} <scomp-stream>` tag is placed on a page. 

Defining Custom Websocket Behaviour
-----------------------------------

You can provide your own websocket_start similar too controller websocket by setting a ws_handler 
containing the name of a websocket handler module in the zotonic context.

Example::

    websocket_start(ReqData, Context) ->
        Context1 = z_context:set(ws_handler, ?MODULE, Context),
        controller_websocket:websocket_start(ReqData, Context).

When passing a custom handler module, the default handler websocket will not be used, but the specified 
one. Controller websocket contains the code for the default zotonic handler. It attaches itself as 
websocket handler to the page session.

It is also possible to configure a custom ``ws_handler`` by specifying it in a dispatch rule.::

    {customws, ["socket", "custom"], controller_websocket, [{ws_handler, my_ws_handler}]}

.. highlight:: erlang
       
WebSocket Handler API
---------------------

In order to implement your own websocket handler you have to implement four callback functions. 
When you want to sent a message to the client you call ``controller_websocket:send_data/2``.

Example::

  -module(my_ws_handler).

  %% @doc Called when the websocket is initialized.
  websocket_init(_Context) ->
      erlang:start_timer(1000, self(), <<"Hello!">>),
      ok.

  %% @doc Called when a message arrives on the websocket.
  websocket_message(Msg, Context) ->
      controller_websocket:websocket_send_data(self(), ["You said: ", Msg]).

  %% @doc Called when another type of message arrives.
  websocket_info(Msg, _Context) ->
      controller_websocket:websocket_send_data(self(), Msg),
      erlang:start_timer(5000, self(), <<"Hello again!">>).

  %% @doc Called when the websocket terminates.
  websocket_terminate(Reason, Context) ->
      ok.

