%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009-2014 Marc Worrell
%%
%% @doc Identify files, fetch metadata about an image
%% @todo Recognize more files based on magic number, think of office files etc.

%% Copyright 2009-2014 Marc Worrell, Konstantin Nikiforov
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

-module(z_media_identify).
-author("Marc Worrell <marc@worrell.nl").

%% interface functions
-export([
    identify/2,
	identify/3,
    identify/4,
	identify_file/2,
	identify_file/3,
	identify_file_direct/2,
    extension/1,
    extension/2,
    extension/3,
	guess_mime/1,
    is_mime_vector/1,
    is_mime_compressed/1
]).

-include_lib("zotonic.hrl").


%% @doc Caching version of identify/1. Fetches information about an image, returns width, height, type, etc.
-spec identify(#upload{}|string(), #context{}) -> {ok, Props::list()} | {error, term()}.
identify(#upload{tmpfile=File, filename=Filename}, Context) ->
	identify(File, Filename, Context);
identify(File, Context) ->
	identify(File, File, Context).

-spec identify(#upload{}|string(), string(), #context{}) -> {ok, Props::list()} | {error, term()}.
identify(File, OriginalFilename, Context) ->
    identify(File, File, OriginalFilename, Context).

identify(File, MediumFilename, OriginalFilename, Context) ->
    F = fun() ->
            case m_media:identify(MediumFilename, Context) of
                {ok, _Props} = Result -> Result;
                {error, _Reason} -> identify_file(File, OriginalFilename, Context)
            end
    end,
    z_depcache:memo(F, {media_identify, MediumFilename}, ?DAY, [media_identify], Context).
    


%% @doc Fetch information about a file, returns mime, width, height, type, etc.  First checks if a module
%% has a specific identification methods.
-spec identify_file(File::string(), #context{}) -> {ok, Props::list()} | {error, term()}.
identify_file(File, Context) ->
	identify_file(File, File, Context).

-spec identify_file(File::string(), OriginalFilename::string(), #context{}) -> {ok, Props::list()} | {error, term()}.
identify_file(File, OriginalFilename, Context) ->
    Extension = maybe_extension(File, OriginalFilename),
    case z_notifier:first(#media_identify_file{filename=File, original_filename=OriginalFilename, extension=Extension}, Context) of
        {ok, Props} ->
			{ok, Props};
        undefined -> 
            identify_file_direct(File, OriginalFilename)
	end.

maybe_extension(File, undefined) ->
    maybe_extension(File);
maybe_extension(_File, OriginalFilename) ->
    maybe_extension(OriginalFilename).

maybe_extension(undefined) ->
    "";
maybe_extension(Filename) ->
    z_convert:to_list(z_string:to_lower(filename:extension(Filename))). 

%% @doc Fetch information about a file, returns mime, width, height, type, etc.
-spec identify_file_direct(File::string(), OriginalFilename::string()) -> {ok, Props::list()} | {error, term()}.
identify_file_direct(File, OriginalFilename) ->
    maybe_identify_extension(identify_file_direct_1(File, OriginalFilename), OriginalFilename).

identify_file_direct_1(File, OriginalFilename) ->
    {OsFamily, _} = os:type(),
	case identify_file_os(OsFamily, File, OriginalFilename) of
		{error, _} ->
			%% Last resort, give ImageMagick a try
			identify_file_imagemagick(OsFamily, File);
		{ok, Props} ->
			%% Images, pdf and ps are further investigated by ImageMagick
			case proplists:get_value(mime, Props) of
				"image/" ++ _ -> identify_file_imagemagick(OsFamily, File);
				"application/pdf" -> identify_file_imagemagick(OsFamily, File);
				"application/postscript" -> identify_file_imagemagick(OsFamily, File);
				_Mime -> {ok, Props}
			end
	end.

maybe_identify_extension({error, "identify error: "++_}, OriginalFilename) ->
    {ok, [ {mime, guess_mime(OriginalFilename)} ]};
maybe_identify_extension({ok, [{mime,"application/octet-stream"}]}, OriginalFilename) ->
    {ok, [ {mime, guess_mime(OriginalFilename)} ]};
maybe_identify_extension(Result, _OriginalFilename) ->
    Result.

%% @doc Identify the mime type of a file using the unix "file" command.
-spec identify_file_os(win32|unix, File::string(), OriginalFilename::string()) -> {ok, Props::list()} | {error, term()}.
identify_file_os(win32, _File, OriginalFilename) ->
    {ok, [{mime, guess_mime(OriginalFilename)}]};

identify_file_os(unix, File, OriginalFilename) ->
    SafeFile = z_utils:os_filename(File),
    Mime = z_string:trim(os:cmd("file -b --mime-type "++SafeFile)),
    case re:run(Mime, "^[a-zA-Z0-9_\\-\\.]+/[a-zA-Z0-9\\.\\-_]+$") of
        nomatch -> 
            case Mime of 
                "CDF V2 Document, corrupt:" ++ _ ->
                    % Probably just a semi-illegal variation on a MS Office file, use the extension
                    case guess_mime(OriginalFilename) of
                        "application/msword" -> {ok, [{mime, "application/msword"}]};
                        "application/vnd.ms-excel" -> {ok, [{mime, "application/vnd.ms-excel"}]};
                        "application/vnd.ms-powerpoint" -> {ok, [{mime, "application/vnd.ms-powerpoint"}]};
                        _ -> {error, Mime}
                    end;
                _ ->
                    {error, Mime}
            end;
        {match, _} ->
            case Mime of
                "text/x-c" ->
                    %% "file" does a lousy job recognizing files with curly braces in them.
                    Mime2 = case guess_mime(OriginalFilename) of
                        "text/" ++ _ = MimeFilename -> MimeFilename;
                        "application/x-" ++ _ = MimeFilename -> MimeFilename;
                        "application/json" -> "application/json";
                        _ -> "text/plain"
                    end,
                    {ok, [{mime, Mime2}]};
                "application/x-gzip" ->
                    %% Special case for the often used extension ".tgz" instead of ".tar.gz"
                    case filename:extension(OriginalFilename) of
                        ".tgz" -> {ok, [{mime, "application/x-gzip+tar"}]};
                        _ -> {ok, [{mime, "application/x-gzip"}]}
                    end;
                "application/zip" ->
                    %% Special case for zip'ed office files
                    case guess_mime(OriginalFilename) of
                        "application/vnd.openxmlformats-officedocument." ++ _ = OfficeMime ->
                            {ok, [{mime, OfficeMime}]};
                        _ ->
                            {ok, [{mime, "application/zip"}]}
                    end;
                "application/ogg" ->
                    % The file utility does some miss-guessing
                    case guess_mime(OriginalFilename) of
                        "video/ogg" -> {ok, [{mime, "video/ogg"}]};
                        "audio/ogg" -> {ok, [{mime, "audio/ogg"}]};
                        _ -> {ok, [{mime, "application/ogg"}]}
                    end;
                "application/octet-stream" ->
                    % The file utility does some miss-guessing
                    case guess_mime(OriginalFilename) of
                        "text/csv" -> {ok, [{mime, "text/csv"}]};
                        "application/vnd.oasis.opendocument." ++ _ = ODF -> {ok, [{mime, ODF}]};
                        "application/inspire" -> {ok, [{mime, "application/inspire"}]};
                        "video/mpeg" -> {ok, [{mime, "video/mpeg"}]};
                        "audio/mpeg" -> {ok, [{mime, "audio/mpeg"}]};
                        _ -> {ok, [{mime, "application/octet-stream"}]}
                    end;
                "application/vnd.ms-office" ->
                    % Generic ms-office mime type, check if the filename is more specific
                    case guess_mime(OriginalFilename) of
                        "application/vnd.ms" ++ _ = M -> {ok, [{mime,M}]};
                        "application/msword" -> {ok, [{mime,"application/msword"}]};
                        _ -> {ok, [{mime, "application/vnd.ms-office"}]}
                    end;
                "audio/x-wav" ->
                    case guess_mime(OriginalFilename) of
                        "audio/" ++ _ = M -> {ok, [{mime,M}]};
                        _ -> {ok, [{mime, "audio/x-wav"}]}
                    end;
                _ ->
                    {ok, [{mime, Mime}]}
            end
    end.


%% @doc Try to identify the file using image magick
-spec identify_file_imagemagick(win32|unix, Filename::string()) -> {ok, Props::list()} | {error, term()}.
identify_file_imagemagick(OsFamily, ImageFile) ->
    CleanedImageFile = z_utils:os_filename(ImageFile ++ "[0]"),
    Result    = os:cmd("identify -quiet " ++ CleanedImageFile ++ " 2> " ++ devnull(OsFamily)),
    case Result of
        [] ->
            Err = os:cmd("identify -quiet " ++ CleanedImageFile ++ " 2>&1"),
            ?LOG("identify of ~s failed:~n~s", [CleanedImageFile, Err]),
            {error, "identify error: " ++ Err};
        _ ->
            %% ["test/a.jpg","JPEG","3440x2285","3440x2285+0+0","8-bit","DirectClass","2.899mb"]
            %% sometimes:
            %% test.jpg[0]=>test.jpg JPEG 2126x1484 2126x1484+0+0 DirectClass 8-bit 836.701kb 0.130u 0:02

            %% "/tmp/ztmp-zotonic008prod@miffy.local-1321.452998.868252[0]=>/tmp/ztmp-zotonic008prod@miffy.local-1321.452998.868252 JPEG 1824x1824 1824x1824+0+0 8-bit DirectClass 1.245MB 0.000u 0:00.000"

            Line1 = hd(string:tokens(Result, "\r\n")),
            try
                Words = string:tokens(Line1, " "),
                WordCount = length(Words),
                Words1 = if
                             WordCount > 4 -> 
                                 {A,_B} = lists:split(4, Words),
                                 A;
                             true -> 
                                 Words
                         end,

                [_Path, Type, Dim, _Dim2] = Words1,
                Mime = mime(Type),
                [Width,Height] = string:tokens(Dim, "x"),
                {W1,H1} = maybe_sizeup(Mime, list_to_integer(Width), list_to_integer(Height)),
                Props1 = [{width, W1},
                          {height, H1},
                          {mime, Mime}],
                Props2 = case Mime of
                             "image/" ++ _ ->
                                 [{orientation, exif_orientation(ImageFile)} | Props1];
                             _ -> 
                                Props1
                         end,
                {ok, Props2}
            catch
                X:B ->
                    ?DEBUG({X,B, erlang:get_stacktrace()}),
                    ?LOG("identify of ~p failed - ~p", [CleanedImageFile, Line1]),
                    {error, "unknown result from 'identify': '"++Line1++"'"}
            end
    end.

%% @doc Prevent unneeded 'extents' for vector based inputs.
maybe_sizeup(Mime, W, H) ->
    case is_mime_vector(Mime) of
        true -> {W*2, H*2};
        false -> {W,H}
    end.

is_mime_vector("application/pdf") -> true;
is_mime_vector("application/postscript") -> true;
is_mime_vector("image/svg+xml") -> true;
is_mime_vector(<<"application/pdf">>) -> true;
is_mime_vector(<<"application/postscript">>) -> true;
is_mime_vector(<<"image/svg+xml">>) -> true;
is_mime_vector(_) -> false.


-spec devnull(win32|unix) -> string().
devnull(win32) -> "nul";
devnull(unix)  -> "/dev/null".


%% @spec mime(String) -> MimeType
%% @doc Map the type returned by ImageMagick to a mime type
%% @todo Add more imagemagick types, check the mime types
-spec mime(string()) -> string().
mime("JPEG") -> "image/jpeg";
mime("GIF") -> "image/gif";
mime("TIFF") -> "image/tiff";
mime("BMP") -> "image/bmp";
mime("PDF") -> "application/pdf";
mime("PS") -> "application/postscript";
mime("PS2") -> "application/postscript";
mime("PS3") -> "application/postscript";
mime("PNG") -> "image/png";
mime("PNG8") -> "image/png";
mime("PNG24") -> "image/png";
mime("PNG32") -> "image/png";
mime("SVG") -> "image/svg+xml";
mime(Type) -> "image/" ++ string:to_lower(Type).



%% @doc Return the extension for a known mime type (eg. ".mov").
-spec extension(string()|binary()) -> string().
extension(Mime) -> extension(Mime, undefined).

%% @doc Return the extension for a known mime type (eg. ".mov"). When
%% multiple extensions are found for the given mime type, returns the
%% one that is given as the preferred extension. Otherwise, it returns
%% the first extension.
-spec extension(string()|binary(), string()|binary()|undefined, #context{}) -> string().
extension(Mime, PreferExtension, Context) ->
    case z_notifier:first(#media_identify_extension{mime=maybe_binary(Mime), preferred=maybe_binary(PreferExtension)}, Context) of
        undefined ->
            extension(Mime, PreferExtension);
        Extension ->
            z_convert:to_list(Extension)
    end.

maybe_binary(undefined) -> undefined;
maybe_binary(L) -> z_convert:to_binary(L). 

-spec extension(string()|binary(), string()|binary()|undefined) -> string().
extension("image/jpeg", _PreferExtension) -> ".jpg";
extension(<<"image/jpeg">>, _PreferExtension) -> ".jpg";
extension(Mime, PreferExtension) ->
    Extensions = mimetypes:extensions(z_convert:to_binary(Mime)),
    case PreferExtension of
        undefined ->
            first_extension(Extensions);
        _ ->
            %% convert prefer extension to something that mimetypes likes
            Ext1 = z_convert:to_binary(z_string:to_lower(PreferExtension)),
            Ext2 = case Ext1 of
                       <<$.,Rest/binary>> -> Rest;
                       _ -> Ext1
                   end,
            case lists:member(Ext2, Extensions) of
                true ->
                    [$. | z_convert:to_list(Ext2)];
                false ->
                    first_extension(Extensions)
            end
    end.


first_extension([]) ->
    ".bin";
first_extension(Extensions) ->
    [$. | z_convert:to_list(hd(Extensions))].


%% @spec guess_mime(string()) -> string()
%% @doc  Guess the mime type of a file by the extension of its filename.
-spec guess_mime(string() | binary()) -> string().
guess_mime(File) ->
	case mimetypes:filename(z_convert:to_binary(z_string:to_lower(File))) of
		[Mime|_] -> z_convert:to_list(Mime);
		[] -> "application/octet-stream"
	end.


%% Detect the exif rotation in an image and swaps width/height accordingly.
-spec exif_orientation(string()) -> 1|2|3|4|5|6|7|8.
exif_orientation(InFile) ->
    %% FIXME - don't depend on external command
    case string:tokens(exif_orientation_cmd(InFile), "\n") of
        [] -> 
            1;
        [Line|_] -> 
            FirstLine = z_convert:to_list(z_string:to_lower(Line)),
            case [z_convert:to_list(z_string:trim(X)) || X <- string:tokens(FirstLine, "-")] of
                ["top", "left"] -> 1;
                ["top", "right"] -> 2;
                ["bottom", "right"] -> 3;
                ["bottom", "left"] -> 4;
                ["left", "top"] -> 5;
                ["right", "top"] -> 6;
                ["right", "bottom"] -> 7;
                ["left", "bottom"] -> 8;
                _ -> 1
            end
    end.

exif_orientation_cmd(File) ->
    exif_orientation_cmd_1(os:type(), File).

exif_orientation_cmd_1({win32, _}, File) ->
    os:cmd("exif -m -t Orientation " ++ z_utils:os_filename(File));
exif_orientation_cmd_1({_Unix, _}, File) ->
    os:cmd("LANG=en exif -m -t Orientation " ++ z_utils:os_filename(File)).

%% @doc Given a mime type, return whether its file contents is already compressed or not.
-spec is_mime_compressed(string()) -> boolean().
is_mime_compressed("text/"++_)                               -> false;
is_mime_compressed("image/svgz"++_)                          -> true;
is_mime_compressed("image/svg"++_)                           -> false;
is_mime_compressed("image/"++_)                              -> true;
is_mime_compressed("video/"++_)                              -> true;
is_mime_compressed("audio/x-wav")                            -> false;
is_mime_compressed("audio/"++_)                              -> true;
is_mime_compressed("application/x-compres"++_)               -> true;
is_mime_compressed("application/zip")                        -> true;
is_mime_compressed("application/x-gz"++_)                    -> true;
is_mime_compressed("application/x-rar")                      -> true;
is_mime_compressed("application/x-bzip2")                    -> true;
is_mime_compressed("application/x-font-woff")                -> true;
is_mime_compressed("application/vnd.oasis.opendocument."++_) -> true;
is_mime_compressed("application/vnd.openxml"++_)             -> true;
is_mime_compressed("application/x-shockwave-flash")          -> true;
is_mime_compressed(_)                                        -> false.
