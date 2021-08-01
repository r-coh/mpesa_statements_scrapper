defmodule StatementsReader.CLI do
  @moduledoc """
  This main module of the app and is mostly handy at passing options
  for the app.
  """

  @doc """
  The main/1 function that starts the script.
  It takes parameters of type one word string
  which serves as the options.
  """
  @spec main(String.t()) :: String.t()
  def main(params) do
    params
    |> parse_params()
    |> process
  end

  @doc """
  This function takes the input string and parses it through the
  OptionParser module and assign the various data retrieved to an
  atom.
  """
  def parse_params(params) do
    opts = [
      switches: [
        help: :boolean,
        password: :string,
        json: :boolean,
        sql: :boolean,
        csv: :boolean,
        output: :string
      ],
      aliases: [
        h: :help,
        o: :output,
        p: :password
      ]
    ]

    update_opts = fn opts, k, v ->
      output = opts[:output] || File.cwd!()

      opts
      |> Keyword.put(:output, output)
      |> Keyword.put(k, v)
    end

    params
    |> OptionParser.parse(opts)
    |> case do
      {opts, [path], _} -> {:process, update_opts.(opts, :src, path)}
      {[help: true], _, _} -> :help
      _ -> :help
    end
  end

  @doc """
  The process/1 functions are called depending on the parameters that match those recieved from the parse_params/1 function.
  """
  @spec process(Atom.t()) :: String.t() | {:error, String.t()}
  def process({option}) do
    IO.puts("""
    EXTRACT MPESA STATEMENTS
    ------
    Invalid options, use --help to view usage.
           got: #{inspect(option, pretty: true)}
    ------
    """)
  end

  def process(:help) do
    IO.puts("""
    EXPORT MPESA STATEMENTS TO JSON or SQL
    -------------------------------------------
    Syntax
      `xpesa_parser /path/to/mpesa/statements --password pdf_password [--json, --sql, --csv, --excel] [--output /path/to/output/dir]`

    Run the following commands
    to extract statements to json or sql file.
          `xpesa_parser /path/to/mpesa/statement -p password --json -o /output/dir`
          `xpesa_parser /path/to/mpesa/statement -p password --sql -o /output/dir`
          `xpesa_parser /path/to/mpesa/statement -p password --json --sql -o /output/dir` # creates both exports
          `xpesa_parser /path/to/mpesa/statement -p password --json` # current dir is implied as output
          `xpesa_parser /path/to/mpesa/statement -p password` # json output and current working dir is implied

    -------------------------------------------
    """)
  end

  def process({:process, opts}) do
    opts[:src]
    |> StatementsReader.read_statements(opts)
    |> StatementsReader.prepare_statements()
    |> (fn statements ->
          opts
          |> exports()
          |> Enum.map(&{StatementsReader.Statements, :export_statements, [statements, &1]})
          |> Enum.map(fn {m, f, a} -> Task.async(m, f, a) end)
          |> Task.yield_many()
          |> Enum.map(fn {task, res} -> res || Task.shutdown(task, :brutal_kill) end)
          |> Enum.map(fn {_return, {_, res}} -> res end)
        end).()
    |> (fn paths ->
          """
          EXPORTED MPESA STATEMENTS
          -------------------------------------------
          Results at
                  #{Enum.join(paths, "\n\t")}

          -------------------------------------------
          """
        end).()
    |> IO.puts()
  end

  defp exports(opts) do
    to_json? = {:json, opts[:json] || false}
    to_sql? = {:sql, opts[:sql] || false}
    to_csv? = {:csv, opts[:csv] || false}
    to_excel? = {:xlsx, opts[:excel] || false}

    [to_csv?, to_excel?, to_sql?, to_json?]
    |> check_export_options()
    |> Enum.reduce([], fn
      {format, true}, acc -> acc ++ [[format: format]]
      {_, false}, acc -> acc
    end)
    |> Enum.map(&Keyword.merge(opts, &1))
  end

  defp check_export_options(options) do
    options
    |> Enum.all?(fn {_, state} -> !state end)
    |> case do
      true -> (options -- [{:json, false}]) ++ [{:json, true}]
      false -> options
    end
  end
end
