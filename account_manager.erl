-module(account_manager).
-export([create_account/2, validate_login/2]).

create_account(Username, Password) ->
    io:format("Creating account for ~p~n", [Username]),
    case check_username_exists(Username) of
        {ok, true} ->
            io:format("Username ~p already exists~n", [Username]),
            {notok, "Error: Username already exists\n"};
        {ok, false} ->
            save_account(Username, Password),
            io:format("Account for ~p created successfully~n", [Username]),
            {ok, "Account created\n"};
        {error, _} ->
            io:format("Error occurred while checking username existence for ~p~n", [Username]),
            {error, "Error: An error occurred\n"}
    end.

validate_login(Username, Password) ->
    io:format("Validating login for ~p~n", [Username]),
    case check_username_exists(Username) of
        {ok, true} ->
            case check_username_and_password_exists(Username, Password) of
                {ok, true, Level} ->
                    io:format("Login successful for ~p~n", [Username]),
                    {ok, Level};
                {ok, false, _} ->
                    io:format("Wrong password for ~p~n", [Username]),
                    {notok, "Error: Wrong password\n"}
            end;
        {ok, false} ->
            io:format("Username ~p does not exist~n", [Username]),
            {notok, "Error: Username does not exist\n"};
        {error, _} ->
            io:format("Error occurred while validating login for ~p~n", [Username]),
            {error, "Error: An error occurred\n"}
    end.
    
check_username_and_password_exists(Username, Password) ->
    case file:read_file_info("accounts.txt") of
        {ok, _FileInfo} ->
            check_username_and_password_exists_in_file(Username, Password);
        {error, enoent} ->
            io:format("Accounts file not found while checking credentials for ~p~n", [Username]),
            {ok, false};
        {error, Reason} ->
            io:format("Error ~p while checking credentials for ~p~n", [Reason, Username]),
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
            Tokens = string:tokens(string:strip(Line, right, $\n), " "),
            case Tokens of
                [SavedUsername, SavedPassword, SavedLevel] when SavedUsername =:= Username, SavedPassword =:= Password ->
                    {ok, true, list_to_integer(SavedLevel)};
                _ ->
                    check_username_and_password_exists_in_file(File, Username, Password)
            end;
        eof ->
            {ok, false, 0};
        {error, Reason} ->
            io:format("Error ~p while reading line in credentials file for ~p~n", [Reason, Username]),
            {error, Reason}
    end.
save_account(Username, Password) ->
    InitialLevel = 1,
    {ok, File} = file:open("accounts.txt", [write, append]),
    io:format(File, "~s ~s ~p~n", [Username, Password, InitialLevel]),
    file:close(File),
    io:format("Account for ~p saved successfully~n", [Username]).


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
            Tokens = string:tokens(string:strip(Line, right, $\n), " "),
            case Tokens of
                [SavedUsername, _SavedPassword, _SavedLevel] when SavedUsername =:= Username ->
                    {ok, true};
                _ ->
                    check_username_exists_in_file(File, Username)
            end;
        eof ->
            {ok, false};
        {error, Reason} ->
            io:format("Error ~p while reading line in username check for ~p~n", [Reason, Username]),
            {error, Reason}
    end.