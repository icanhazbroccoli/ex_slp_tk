defmodule ExSlp.Tool do

  @default_slptool "slptool"

  @doc """
  Returns a string that is used for invoking the slptool.
  By default this is simply "slptool" per the standard debian package name, but config.exs may override the value
  """
  def slptool do
    Application.get_env(
      :ex_slp, :slptool, @default_slptool)
  end

  @doc """
  Checks the status of `slptool` on the current system.
  Returns:
      { :ok, message } # in case of success
      { :not_executable, message }
      # in case the tool is installed but is not executable by the current user
      { :error, message } # otherwise
  """
  def status do
    {:ok, executable} = String.split(slptool()) |> Enum.fetch(0)
    case System.find_executable(executable) do
      nil -> { :cmd_unknown, "The command #{executable} could not be found. Check your $PATH ENV variable." }
      { error, error_code } -> { :error, error, error_code }
      path ->
        path = String.strip( path )
        case System.cmd( "test", [ "-x", path ] ) do
          { "", 0 } -> { :ok, "The toolkit is set up." }
          { "", 1 } -> { :not_executable, "The file #{path} is not executable for the current user." }
          { error, error_code } -> { :error, error, error_code }
        end
    end
  end

  @doc """
  Executes `slptool` command `cmd` with `args` as
  command arguments and `opts` as the list of post-command options.
  Returns:
      { :ok, response } # in case of success,
      { :error, message } # otherwise.
  """
  def exec_cmd( args, cmd ), do: exec_cmd( args, cmd, [] )
  def exec_cmd( args, cmd, opts ) do
    # treat the slptool invocation string as if it might itself
    # be a command followed by arguments For example:
    # "docker run --rm vcrhonek/openslp slptool"
    [invocation | initial_args] = String.split(slptool())
    case System.cmd( invocation, initial_args ++ args ++ [ cmd | opts ] ) do
        { res, 0 } ->
          { :ok, res |> String.strip }
        { err, 1 } -> { :error, err |> String.strip }
    end
  end

  @doc """
    Gets the current slp toolkit version.
    Returns:
        { major, minor, patch } # if the toolkit is installed
        nil # otherwise
    Example:
        ExSlp.Tool.version
        > { 1, 2, 1 }

        case ExSlp.Tool.version do
          { 1, _, _ } -> # do v1 specific things
          { 2, _, _ } -> # do v2 specific things
        end
  """
  def version do
    case exec_cmd( [], "-v" ) do
      { :ok, res } ->
        case String.split( res, "\n" )
          |> Enum.filter( fn str ->
            Regex.match?( ~r/slptool\sversion/, str )
          end )
          |> List.first do
            nil -> nil
            version_str ->
              case Regex.run( ~r/([\d\.]+)$/, version_str ) do
                nil -> nil
                [ _, ver ] -> ver |> String.split(".")
                                  |> Enum.map( &String.to_integer/1 )
                                  |> List.to_tuple
                _ -> nil
              end
          end
      _ -> nil
    end
  end

end
