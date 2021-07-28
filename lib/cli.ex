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
        output: :string
      ],
      aliases: [
        h: :help,
        o: :output,
        p: :password
      ]
    ]

    params
    |> OptionParser.parse(opts)
    |> case do
      {[help: true], _, _} -> :help
      {opts, [path], _} -> {:process, Keyword.put(opts, :src, path)}
    end
  end

  @doc """
  The process/1 functions are called depending on the parameters that match those recieved from the parse_params/1 function.
  """
  @spec process(Atom.t()) :: String.t() | {:error, String.t()}
  def process({option}) do
    IO.puts("""
    SCRY
    ------
    Invalid options, use --help to view usage.
           got: #{inspect(option, pretty: true)}
    ------
    """)
  end

  def process(:help) do
    IO.puts("""
    SCRY
    -------------------------------------------
    Syntax
      `xpesa_parser /path/to/mpesa/statements --password pdf_password [--json, --sql] [--output /path/to/output/dir]`

    Run the following commands
    to extract statements to json or sql file.
          `xpesa_parser /path/to/mpesa/statement -p password --json -o /output/dir`
          `xpesa_parser /path/to/mpesa/statement -p password --sql -o /output/dir`
          `xpesa_parser /path/to/mpesa/statement -p password --json --sql -o /output/dir`
          `xpesa_parser /path/to/mpesa/statement -p password --json` # current dir is implied as output
          `xpesa_parser /path/to/mpesa/statement -p password` # json output and current working dir is implied

    -------------------------------------------
    """)
  end

  def process({:process, opts}) do
    password = opts[:password]
    src = opts[:src]
    # to_json? = opts[:json] || true
    # to_sql? = opts[:sql] || false
    output = opts[:output]

    # Set password
    System.put_env("PDF_STATEMENT_PASSWORD", password)

    src
    |> StatementsReader.read_statements(opts)
    |> StatementsReader.prepare_statements()
    |> (fn statements ->
          [
            {StatementsReader.Statements, :export_to_json, [statements, output]}
            # {StatementsReader.Statements, :export_to_sql, [statements, output]}
          ]
          |> Enum.map(fn {m, f, a} -> Task.async(m, f, a) end)
          |> Task.yield_many()
          |> Enum.map(fn {task, res} -> res || Task.shutdown(task, :brutal_kill) end)
          |> Enum.map(fn {_return, res} -> res end)
          |> (&{:ok, &1}).()
        end).()
  end
end
