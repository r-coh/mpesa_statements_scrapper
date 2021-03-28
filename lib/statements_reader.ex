defmodule StatementsReader do
  alias StatementsReader.Statements
  alias StatementsReader.Statement
  alias StatementsReader.Utils

  @spec read_statements(Path.t()) :: Statement.t() | list(Statement.t())
  def read_statements(path) do
    path
    |> Utils.check_path()
    |> case do
      {:dir, path} ->
        path |> Utils.filter_statements() |> Enum.map(&read_statements(&1))

      {:file, path} ->
        path
        |> Statements.read_statement()
        |> Statements.parse_statement_info()
        |> Statements.parse_statement_summary()
        |> Statements.parse_statement_detail()
        |> CRUD.clean()
    end
  end

  def prepare_statements(%Statement{} = statement) do
    statement
    |> Statements.prepare_info()
    |> Statements.prepare_summary()
    |> Statements.prepare_detail()
    |> CRUD.format()
  end
end
