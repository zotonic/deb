%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @doc Handles all ajax postback calls

%% Copyright 2009 Marc Worrell
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(resource_postback).
-author("Marc Worrell <marc@worrell.nl>").

-export([
    init/1, 
    forbidden/2,
    malformed_request/2,
    allowed_methods/2,
    content_types_provided/2,
    process_post/2
    ]).

-include_lib("webmachine_resource.hrl").
-include_lib("include/zotonic.hrl").

init(_Args) -> {ok, []}.

malformed_request(ReqData, _Context) ->
    Context1 = z_context:new(ReqData, ?MODULE),
    Context2 = z_context:ensure_qs(Context1),
    case z_context:get_q("postback", Context2) of
        undefined ->
            ?WM_REPLY(true, Context2);
        _ ->
            ?WM_REPLY(false, Context2)
    end.

forbidden(ReqData, Context) ->
    Context1 = ?WM_REQ(ReqData, Context),
    %% TODO: prevent that we make a new ua session or a new page session, fail when a new session is needed
    Context2 = z_context:ensure_all(Context1),
    ?WM_REPLY(false, Context2).

allowed_methods(ReqData, Context) ->
    {['POST'], ReqData, Context}.

content_types_provided(ReqData, Context) -> 
    %% When handling a POST the content type function is not used, so supply false for the function.
    { [{"application/x-javascript", false}], ReqData, Context }.

process_post(ReqData, Context) ->
    Context1 = ?WM_REQ(ReqData, Context),
    EventContext = case z_context:get_q("postback", Context1) of
        "notify" ->
            Message = z_context:get_q("z_msg", Context1),
            TriggerId1 = undefined,
            case z_notifier:first({postback_notify, Message}, Context1) of
                undefined -> Context1;
                #context{} = ContextNotify -> ContextNotify
            end;
        Postback ->
            {EventType, TriggerId, TargetId, Tag, Module} = z_utils:depickle(Postback, Context1),

            TriggerId1 = case TriggerId of
                undefined -> z_context:get_q("z_trigger_id", Context1);
                _         -> TriggerId
            end,

            ContextRsc = z_context:set_resource_module(Module, Context1),
            case EventType of
                "submit" -> 
                    case z_validation:validate_query_args(ContextRsc) of
                        {ok, ContextEval} ->   
                            Module:event({submit, Tag, TriggerId1, TargetId}, ContextEval);
                        {error, ContextEval} ->
                            %% Posted form did not validate, return any errors.
                            ContextEval
                    end;
                _ -> 
                    Module:event({postback, Tag, TriggerId1, TargetId}, ContextRsc)
            end
    end,

    Script      = z_script:get_script(EventContext),
    CometScript = z_session_page:get_scripts(EventContext#context.page_pid),
    
    % Remove the busy mask from the element that triggered this event.
    Script1 = case TriggerId1 of 
        undefined -> Script;
        FormId -> [Script, " z_unmask('",z_utils:js_escape(FormId),"');" ]
    end,
    
    % Send back all the javascript.
    RD  = z_context:get_reqdata(EventContext),
    RD1 = case wrq:get_req_header_lc("content-type", ReqData) of
        "multipart/form-data" ++ _ ->
            RDct = wrq:set_resp_header("Content-Type", "text/html; charset=utf-8", RD),
            case z_context:document_domain(EventContext) of
                undefined ->
                    wrq:append_to_resp_body([
                            "<textarea>", Script1, CometScript, "</textarea>"
                            ], RDct);
                DocumentDomain ->
                    wrq:append_to_resp_body([
                            <<"<script>document.domain=\"">>, DocumentDomain,<<"\";</script><textarea>">>,
                            Script1, CometScript, "</textarea>"
                            ], RDct)
            end;
        _ ->
            wrq:append_to_resp_body([Script1, CometScript], RD)
    end,

    ReplyContext = z_context:set_reqdata(RD1, EventContext),
    ?WM_REPLY(true, ReplyContext).
