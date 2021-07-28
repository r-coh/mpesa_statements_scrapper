defmodule StatementsReader do
  alias StatementsReader.Statements
  alias StatementsReader.Statement
  alias StatementsReader.Utils

  @spec read_statements(Path.t() | {:path, Path.t()} | {:dir, Path.t()}, list()) ::
          Statement.t() | list(Statement.t())

  def read_statements(_, opts \\ [])

  def read_statements({:file, path}, opts) do
    path
    |> Statements.read_statement(opts)
    |> Statements.parse_statement_info()
    |> Statements.parse_statement_summary()
    |> Statements.parse_statement_detail()
    |> CRUD.clean()
  end

  def read_statements({:dir, path}, opts) do
    path
    |> Utils.filter_statements()
    |> Enum.map(&Task.async(__MODULE__, :read_statements, [&1, opts]))
    |> Task.yield_many()
    |> Stream.map(fn {task, res} -> res || Task.shutdown(task, :brutal_kill) end)
    |> Stream.map(fn
      {:ok, res} -> res
      _ -> nil
    end)
    |> Stream.filter(&(not is_nil(&1)))
    |> Enum.to_list()
  end

  def read_statements(path, opts) do
    path
    |> Utils.check_path()
    |> read_statements(opts)
  end

  @spec prepare_statements(Statement.t() | list(Statement.t())) ::
          list(Statement.t()) | Statement.t()
  def prepare_statements([%Statement{} | _] = statements),
    do: Enum.map(statements, &prepare_statements(&1))

  def prepare_statements(%Statement{} = statement) do
    statement
    |> Statements.prepare_info()
    |> Statements.prepare_summary()
    |> Statements.prepare_detail()
    |> CRUD.format()
  end
end
