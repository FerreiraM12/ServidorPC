-module(account_manager).
-export([create_account/2, validate_login/2]).

create_account(Username, Password) ->
    case check_username_exists(Username) of
        {ok, true} ->
            {notok, "Error: Username already exists\n"};
        {ok, false} ->
            save_account(Username, Password),
            {ok, "Account created\n"};
        {error, _} ->
            {error, "Error: An error occurred\n"}
    end.

validate_login(Username, Password) ->
    case check_username_exists(Username) of
        {ok, true} ->
            case check_username_and_password_exists(Username, Password) of
                {ok, true} ->
                    {ok, "Login successful\n"};
                {ok, false} ->
                    {notok, "Error: Wrong password\n"}
            end;
        {ok, false} ->
            {notok, "Error: Username does not exist\n"};
        {error, _} ->
            {error, "Error: An error occurred\n"}
    end.
    
check_username_and_password_exists(Username, Password) ->
    case file:read_file_info("accounts.txt") of
        {ok, _FileInfo} ->
            check_username_and_password_exists_in_file(Username, Password);
        {error, enoent} ->
            {ok, false};
        {error, Reason} ->
            {error, Reason}
    end.

check_username_and_password_exists_in_file(Username, Password) ->
    {ok, File} = file:open("accounts.txt", [read]),
    Result = check_username_and_password_exists_in_file(File, Username, Password),
    file:close(File),
    Result.

check_username_and_password_exists_in_file(File, Username, Password) ->
    case file:read_line(File) of
        {ok, Line} ->
            [SavedUsername, SavedPassword, _SavedLevel] = string:tokens(Line, " "),
            case {SavedUsername, SavedPassword} of
                {Username, Password} ->
                    {ok, true};
                _ ->
                    check_username_and_password_exists_in_file(File, Username, Password)
            end;
        eof ->
            {ok, false};
        {error, Reason} ->
            {error, Reason}
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
            [SavedUsername, _SavedPassword, _SavedLevel] = string:tokens(Line, " "),
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