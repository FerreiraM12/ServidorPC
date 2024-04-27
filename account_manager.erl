-module(account_manager).
-export([process_request/1]).

process_request(Data) ->
    {Username, Password} = parse_data(Data),
    case check_username_exists(Username) of
        {ok, true} ->
            "Erro: O nome de utilizador já existe\n";
        {ok, false} ->
            ok = save_account(Username, Password),
            "Conta criada com sucesso\n";
        {error, _} ->
            "Erro: Ocorreu algum erro a confirmar utilizadores\n"
    end.

save_account(Username, Password) ->
    {ok, File} = file:open("accounts.txt", [write, append]),
    io:format(File, "~s ~s ~s~n", [Username, Password, "1"]),
    file:close(File).

check_username_exists(Username) ->
    case file:read_file_info("accounts.txt") of
        {ok, _FileInfo} ->
            check_username_exists_in_file(Username);
        {error, enoent} ->
            {ok, false};
        {error, Reason} ->
            {error, Reason}
    end.

check_username_exists_in_file(Username) ->
    {ok, File} = file:open("accounts.txt", [read]),
    Result = check_username_exists_in_file(File, Username),
    file:close(File),
    Result.

check_username_exists_in_file(File, Username) ->
    case file:read_line(File) of
        {ok, Line} ->
            [SavedUsername, _SavedPassword] = string:split(Line, " "),
            case SavedUsername of
                Username ->
                    {ok, true};
                _ ->
                    check_username_exists_in_file(File, Username)
            end;
        eof ->
            {ok, false};
        {error, Reason} ->
            {error, Reason}
    end.

parse_data(Data) ->
    [Username, Password] = string:split(Data, " "),
    {Username, Password}.
