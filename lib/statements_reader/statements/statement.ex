defmodule StatementsReader.Statement do
  @enforce_keys [:raw_data, :valid?, :state]
  @derive {Jason.Encoder, only: [:info, :summary, :data, :page]}
  defstruct [:raw_data, :info, :summary, :data, :valid?, :state, :page]
end

defprotocol CRUD do
  alias StatementsReader.Statement

  @spec new(map) :: Statement.t()
  @spec update(Statement.t(), map) :: Statement.t()
  @spec clean(Statement.t()) :: Statement.t()
  @spec format(Statment.t()) :: Statement.t()

  def new(map)
  def update(statement, map)
  def clean(statement)
  def format(statement)
end

defimpl CRUD, for: Map do
  def new(%{raw_data: raw} = data),
    do: %StatementsReader.Statement{raw_data: raw, valid?: true, state: :new} |> Map.merge(data)

  def update(%StatementsReader.Statement{} = stmnt, params),
    do: Map.merge(stmnt, params)

  def clean(%StatementsReader.Statement{valid?: true} = statmnt),
    do: %{statmnt | state: :cleaned}

  def format(%StatementsReader.Statement{} = d), do: d
end

defimpl CRUD, for: Any do
  def new(data), do: %StatementsReader.Statement{raw_data: data, valid?: false, state: :new}
  def update(%StatementsReader.Statement{}, _map), do: raise("Unsupported!")
  def clean(%StatementsReader.Statement{} = d), do: d
  def format(%StatementsReader.Statement{} = d), do: d
end

defimpl CRUD, for: StatementsReader.Statement do
  def new(value), do: %{value | valid?: true, state: :new}
  def update(value, params), do: Map.merge(value, params)

  def clean(%{data: {_, data}} = value),
    do: %{
      value
      | state: :cleaned,
        raw_data: nil,
        page: Map.put(value.page || %{}, :total_transactions, Enum.count(data))
    }

  def format(%{data: data} = value),
    do: %{
      value
      | state: :formatted,
        page: Map.put(value.page, :parsed_transactions, Enum.count(data))
    }
end
