%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% Date: 2009-04-17
%%
%% @doc This server will install the database when started. It will always return ignore to the supervisor.
%% This server should be started after the database pool but before any database queries will be done.

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

-module(z_installer).
-author("Marc Worrell <marc@worrell.nl").

%% gen_server exports
-export([start_link/1]).

-include_lib("zotonic.hrl").

%%====================================================================
%% API
%%====================================================================
%% @spec start_link(SiteProps) -> {ok,Pid} | ignore | {error,Error}
%% @doc Install zotonic on the databases in the PoolOpts, skips when already installed.
start_link(SiteProps) when is_list(SiteProps) ->
    install_check(SiteProps).

install_check(SiteProps) ->
    %% Check if the config table exists, if so then assume that all is ok
    {host, Host} = proplists:lookup(host, SiteProps),
    lager:md([
        {site, Host},
        {module, ?MODULE}
      ]),
    Context = z_context:new(Host),
    case z_db:has_connection(Context) of
        true ->
            case z_db_pool:test_connection(Context) of
                ok ->
                    Options0 = z_db_pool:get_database_options(Context),
                    Options = lists:filter(fun({dbpassword,_}) -> false; (_) -> true end, Options0),
                    case z_db:table_exists(config, Context) of
                        false ->
                            %% Install database
                            lager:warning("~p: Installing database with db options: ~p", [z_context:site(Context), Options]),
                            z_install:install(Context),
                            ignore;
                        true ->
                            %% Normal startup, do upgrade / check
                            ok = z_db:transaction(
                                   fun(Context1) ->
                                           C = z_db_pgsql:get_raw_connection(Context1),
                                           Database = proplists:get_value(dbdatabase, Options),
                                           Schema = proplists:get_value(dbschema, Options),
                                           ok = upgrade(C, Database, Schema),
                                           ok = sanity_check(C, Database, Schema)
                                   end,
                                   Context),
                            ignore
                    end;
                {error, Reason} ->
                    lager:warning("~p: Database connection failure!", [z_context:site (Context)]),
                    lager:warning("~p", [Reason]),
                    stop
            end;
        false ->
            ignore
    end.

has_table(C, Table, Database, Schema) ->    
    {ok, _, [{HasTable}]} = pgsql:equery(C, "
            select count(*) 
                                         from information_schema.tables 
                                         where table_catalog = $1 
                                         and table_name = $3 
                                         and table_schema = $2
                                         and table_type = 'BASE TABLE'", [Database, Schema, Table]),
    HasTable =:= 1.


%% Check if a column in a table exists by querying the information schema.
has_column(C, Table, Column, Database, Schema) ->
    {ok, _, [{HasColumn}]} = pgsql:equery(C, "
            select count(*) 
                                          from information_schema.columns 
                                          where table_catalog = $1 
                                          and table_schema = $2
                                          and table_name = $3 
                                          and column_name = $4", [Database, Schema, Table, Column]),
    HasColumn =:= 1.

get_column_type(C, Table, Column, Database, Schema) ->
    {ok, _, [{ColumnType}]} = pgsql:equery(C, "
            select data_type
                                           from information_schema.columns 
                                           where table_catalog = $1 
                                           and table_schema = $2
                                           and table_name = $3 
                                           and column_name = $4", [Database, Schema, Table, Column]),
    ColumnType.


%% Upgrade older Zotonic versions.
upgrade(C, Database, Schema) ->
    ok = install_acl(C, Database, Schema),
    ok = install_identity_is_verified(C, Database, Schema),
    ok = install_identity_verify_key(C, Database, Schema),
    ok = install_persist(C, Database, Schema),
    ok = drop_visitor(C, Database, Schema),
    ok = extent_mime(C, Database, Schema),
    ok = install_task_due(C, Database, Schema),
    ok = install_module_schema_version(C, Database, Schema),
    ok = install_geocode(C, Database, Schema),
    ok = install_rsc_gone(C, Database, Schema),
    ok = install_rsc_page_path_log(C, Database, Schema),
    ok = upgrade_config_schema(C, Database, Schema),
    ok = install_medium_log(C, Database, Schema),
    ok = install_pivot_location(C, Database, Schema),
    ok = install_edge_log(C, Database, Schema),
    ok.

upgrade_config_schema(C, Database, Schema) ->
    case get_column_type(C, "config", "value", Database, Schema) of
        <<"text">> -> 
            ok;
        _ ->
            {ok,[],[]} = pgsql:squery(C, "alter table config alter column value type text"),
            ok
    end.


install_acl(C, Database, Schema) ->
    %% Remove group, rsc_group, group_id
    HasRscGroup = has_table(C, "rsc_group", Database, Schema),
    HasGroup = has_table(C, "group", Database, Schema),
    case HasRscGroup andalso HasGroup of
        true ->
            pgsql:squery(C, "alter table rsc drop column group_id cascade"),
            pgsql:squery(C, "drop table rsc_group cascade"),
            pgsql:squery(C, "drop table \"group\" cascade"),
            pgsql:squery(C, "delete from module where name='mod_admin_group'"),
            {ok, 1} = pgsql:equery(C, "insert into module (name, is_active) values ($1, true)", ["mod_acl_adminonly"]),
            ok;
        false ->
            ok
    end.


install_persist(C, Database, Schema) ->
    case has_table(C, "persistent", Database, Schema) of
        false ->
            {ok,[],[]} = pgsql:squery(C, "create table persistent ( "
                                      "  id character varying(32) not null,"
                                      "  props bytea,"
                                      "  created timestamp with time zone NOT NULL DEFAULT now(),"
                                      "  modified timestamp with time zone NOT NULL DEFAULT now(),"
                                      "  CONSTRAINT persistent_pkey PRIMARY KEY (id)"
                                      ")"),
            ok;
        true ->
            ok
    end.

install_rsc_page_path_log(C, Database, Schema) ->
    case has_table(C, "rsc_page_path_log", Database, Schema) of
        false ->
            {ok, [], []} = pgsql:squery(C, z_install:rsc_page_path_log()),
            pgsql:squery(C, z_install:rsc_page_path_log_fki()),
            ok;
        true ->
            case pgsql:equery(C,
                             "select count(*)
                              from information_schema.referential_constraints
                              where constraint_catalog = $1
                                and constraint_schema = $2
                                and constraint_name = 'rsc_page_path_log_fkey'",
                             [Database, Schema])
            of
                {ok, [_], [{1}]} ->
                    {ok, [], []} = pgsql:squery(C, "ALTER TABLE rsc_page_path_log "
                                        "DROP CONSTRAINT rsc_page_path_log_fkey, "
                                        "ADD CONSTRAINT fk_rsc_page_path_log_id FOREIGN KEY (id) "
                                        "    REFERENCES rsc(id)"
                                        "    ON UPDATE CASCADE ON DELETE CASCADE"),
                    pgsql:squery(C, z_install:rsc_page_path_log_fki()),
                    ok;
                {ok, [_], [{0}]} ->
                    ok
            end
    end.


drop_visitor(C, Database, Schema) ->
    case has_table(C, "visitor_cookie", Database, Schema) of
        true ->
            {ok, _N} = pgsql:squery(C, 
                                    "insert into persistent (id,props) "
                                    "select c.cookie, v.props from visitor_cookie c join visitor v on c.visitor_id = v.id"),
            pgsql:squery(C, "drop table visitor_cookie cascade"),
            pgsql:squery(C, "drop table visitor cascade"),
            ok;
        false ->
            ok
    end.


extent_mime(C, Database, Schema) ->
    {ok, _, [{Length}]} = pgsql:equery(C, "
            select character_maximum_length 
                                       from information_schema.columns 
                                       where table_catalog = $1 
                                       and table_schema = $2
                                       and table_name = $3 
                                       and column_name = $4", [Database, Schema, "medium", "mime"]),
    case Length < 128 of
        true ->
            {ok, [], []} = pgsql:squery(C, "alter table medium alter column mime type character varying(128)");
        false ->
            nop
    end,
    ok.


install_identity_is_verified(C, Database, Schema) ->
    case has_column(C, "identity", "is_verified", Database, Schema) of
        true -> 
            ok;
        false ->
            {ok, [], []} = pgsql:squery(C, "alter table identity "
                                        "add column is_verified boolean not null default false"),
            {ok, [], []} = pgsql:squery(C, "update identity set is_verified = true where key = 'username_pw'"),
            ok
    end.

install_identity_verify_key(C, Database, Schema) ->
    case has_column(C, "identity", "verify_key", Database, Schema) of
        true -> 
            ok;
        false ->
            {ok, [], []} = pgsql:squery(C, "alter table identity "
                                        "add column verify_key character varying(32), "
                                        "add constraint identity_verify_key_unique UNIQUE (verify_key)"),
            ok
    end.


install_task_due(C, Database, Schema) ->
    case has_column(C, "pivot_task_queue", "due", Database, Schema) of
        true -> 
            ok;
        false ->
            {ok, [], []} = pgsql:squery(C, "alter table pivot_task_queue add column due timestamp "),
            ok
    end.


install_module_schema_version(C, Database, Schema) ->
    case has_column(C, "module", "schema_version", Database, Schema) of
        true -> 
            ok;
        false ->
            {ok, [], []} = pgsql:squery(C, "alter table module add column schema_version int "),
            Predefined = ["mod_twitter", "mod_mailinglist", "mod_menu", "mod_survey", "mod_acl_simple_roles", "mod_contact"],
            [
             {ok, _} = pgsql:equery(C, "UPDATE module SET schema_version=1 WHERE name=$1 AND is_active=true", [M]) || M <- Predefined
            ],
            ok
    end.

%% make sure the geocode is a bigint (psql doesn't have unsigned bigint)
install_geocode(C, Database, Schema) ->
    case get_column_type(C, "rsc", "pivot_geocode", Database, Schema) of
        <<"character varying">> ->
            {ok, [], []} = pgsql:squery(C, "alter table rsc drop column pivot_geocode"),
            {ok, [], []} = pgsql:squery(C, "alter table rsc add column pivot_geocode bigint,"
                                        " add column pivot_geocode_qhash bytea"),
            {ok, [], []} = pgsql:squery(C, "CREATE INDEX rsc_pivot_geocode_key ON rsc (pivot_geocode)"),
            ok;
        <<"bigint">> ->
            %% 0.9dev was missing a column definition in the z_install.erl
            case has_column(C, "rsc", "pivot_geocode_qhash", Database, Schema) of
                true -> 
                    ok;
                false ->
                    {ok, [], []} = pgsql:squery(C, "alter table rsc add column pivot_geocode_qhash bytea"),
                    ok
            end
    end.

%% Install the table tracking deleted (or moved) resources
install_rsc_gone(C, Database, Schema) ->
    case has_table(C, "rsc_gone", Database, Schema) of
        false ->
            install_rsc_gone_1(C);
        true ->
            case has_column(C, "rsc_gone", "new_id", Database, Schema) of
                false ->
                    _ = pgsql:squery(C, "DROP TABLE rsc_gone"),
                    install_rsc_gone_1(C);
                true ->
                    ok
            end
    end.

install_rsc_gone_1(C) ->
    {ok,[],[]} = pgsql:squery(C, "create table rsc_gone ( "
                              "  id bigint not null,"
                              "  new_id bigint,"
                              "  new_uri character varying(250),"
                              "  version int not null, "
                              "  uri character varying(250),"
                              "  name character varying(80),"
                              "  page_path character varying(80),"
                              "  is_authoritative boolean NOT NULL DEFAULT true,"
                              "  creator_id bigint,"
                              "  modifier_id bigint,"
                              "  created timestamp with time zone NOT NULL DEFAULT now(),"
                              "  modified timestamp with time zone NOT NULL DEFAULT now(),"
                              "  CONSTRAINT rsc_gone_pkey PRIMARY KEY (id)"
                              ")"),
    {ok, [], []} = pgsql:squery(C, "CREATE INDEX rsc_gone_name ON rsc_gone(name)"),
    {ok, [], []} = pgsql:squery(C, "CREATE INDEX rsc_gone_page_path ON rsc_gone(page_path)"),
    {ok, [], []} = pgsql:squery(C, "CREATE INDEX rsc_gone_modified ON rsc_gone(modified)"),
    ok.

%% Table with all uploaded filenames, used to ensure unique filenames in the upload archive
install_medium_log(C, Database, Schema) ->
    case has_table(C, "medium_log", Database, Schema) of
        false ->
            {ok,[],[]} = pgsql:squery(C, z_install:medium_log_table()),
            {ok,[],[]} = pgsql:squery(C, z_install:medium_update_function()),
            {ok,[],[]} = pgsql:squery(C, z_install:medium_update_trigger()),
            {ok, _} = pgsql:squery(C,
                                   "
                                insert into medium_log (usr_id, filename, created)
                                   select r.creator_id, m.filename, m.created
                                   from medium m join rsc r on r.id = m.id
                                   where m.filename is not null
                                   and m.filename <> ''
                                   and m.is_deletable_file
                                   "),
            {ok, _} = pgsql:squery(C,
                                   "
                                insert into medium_log (usr_id, filename, created)
                                   select r.creator_id, m.preview_filename, m.created
                                   from medium m join rsc r on r.id = m.id
                                   where m.preview_filename is not null
                                   and m.preview_filename <> ''
                                   and m.is_deletable_preview
                                   "),
            ok;
                                       true ->
                                          ok
                                  end.


install_pivot_location(C, Database, Schema) ->
    Added = lists:foldl(fun(Col, Acc) ->
                          case has_column(C, "rsc", Col, Database, Schema) of
                              true -> 
                                  Acc;
                              false ->
                                  {ok, [], []} = pgsql:squery(C, "alter table rsc add column " ++ Col ++ " float"),
                                  true
                          end
                        end,
                        false,
                        ["pivot_location_lat", "pivot_location_lng"]),
    case Added of
        true ->
            {ok, [], []} = pgsql:squery(C, "CREATE INDEX rsc_pivot_location_key ON rsc (pivot_location_lat, pivot_location_lng)"),
            ok;
        false ->
            ok
    end.



%% Table with all uploaded filenames, used to ensure unique filenames in the upload archive
install_edge_log(C, Database, Schema) ->
    case has_table(C, "edge_log", Database, Schema) of
        false ->
            {ok,[],[]} = pgsql:squery(C, z_install:edge_log_table()),
            {ok,[],[]} = pgsql:squery(C, z_install:edge_log_function()),
            {ok,[],[]} = pgsql:squery(C, z_install:edge_log_trigger()),
            ok;
         true ->
            ok
    end.


%% Perform some simple sanity checks
sanity_check(C, _Database, _Schema) ->
    ensure_module_active(C, "mod_authentication"),
    ok.

ensure_module_active(C, Module) ->
    case pgsql:equery(C, "select is_active from module where name = $1", [Module]) of
        {ok, _, [{true}]} ->
            ok;
        {ok, _, [{false}]} ->
            {ok, 1} = pgsql:equery(C, "update module set is_active = true where name = $1", [Module]);
        _ ->
            {ok, 1} = pgsql:equery(C, "insert into module (name, is_active) values ($1, true)", [Module])
    end.
