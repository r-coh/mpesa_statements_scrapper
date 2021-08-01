defmodule CSV do
  def encode!(data) when is_list(data) do
    verify_match? = fn ->
      keys = data |> hd |> Map.keys()
      Enum.all?(data, &(Map.keys(&1) == keys))
    end

    if verify_match? do
      keys = data |> hd |> Map.keys() |> List.to_tuple()

      data =
        data |> Enum.map(&(&1 |> Enum.reduce({}, fn {_, v}, acc -> Tuple.append(acc, v) end)))

      ([keys] ++ data)
      |> Enum.map(&(&1 |> Tuple.to_list() |> Enum.join(",")))
      |> Enum.join("\n")
    end
  end
end

defmodule Excel do
  alias Elixlsx.{Workbook, Sheet}

  def encode!(data) when is_list(data) do
    header = data |> hd |> Map.keys() |> Enum.map(&(&1 |> to_string() |> String.upcase()))

    rows =
      data
      |> Enum.map(fn i -> i |> Enum.reduce([], fn {_, v}, acc -> acc ++ [stringify(v)] end) end)

    %Workbook{sheets: [%Sheet{name: "Mpesa statements extracted.", rows: [header] ++ rows}]}
  end

  defp stringify(data) when is_atom(data), do: to_string(data)
  defp stringify(data), do: data
end

defmodule SQL do
  def encode!(data, opts \\ []) when is_list(data) do
    sample = hd(data)
    table = create_table_statement(sample, opts)
    indices = create_indices_statement(sample, opts)
    records = insert_record_statment(data, opts)
    table <> "\n" <> indices <> "\n" <> records <> "\n"
  end

  def create_table_statement(object, opts) do
    with_key_and_type = fn
      {k, v}, acc when is_bitstring(v) -> acc ++ [{k, v, "#{k} char(255)"}]
      {k, v}, acc when is_integer(v) -> acc ++ [{k, v, "#{k} int"}]
      {k, v}, acc when is_map(v) -> acc ++ [{k, v, "#{k} jsonb"}]
      {k, v}, acc when is_float(v) -> acc ++ [{k, v, "#{k} double precision"}]
      {k, v}, acc -> acc ++ [{k, v, "#{k} char(50)"}]
    end

    parse_field_opts = fn {_, _, _} = rec, opts ->
      # todo: better type checking and setup
      opts
      |> Enum.reduce(rec, fn
        :not_null, {k, v, sql} -> {k, v, sql <> " NOT NULL"}
        {:default, d}, {k, v, sql} -> {k, v, sql <> " DEFAULT '#{d}'"}
        :text, {k, v, sql} -> {k, v, String.replace(sql, ~r/\([0-9]+\)/, "(255)")}
        any, acc -> any |> IO.inspect(label: "ala") |> (fn _ -> acc end).()
      end)
    end

    add_defaults = fn {k, _, _} = rec, opts ->
      case opts[k] do
        [_ | _] = opts -> parse_field_opts.(rec, opts)
        _ -> rec
      end
    end

    name = opts[:name] || raise("table name required, got #{inspect(opts, pretty: true)}")
    name = String.downcase(name)

    object
    |> Enum.reduce([], &with_key_and_type.(&1, &2))
    |> Stream.map(&add_defaults.(&1, opts[:opts]))
    |> Stream.map(fn {_, _, statement} -> statement end)
    |> Stream.map(&("\s\s" <> &1))
    |> Enum.join(",\n")
    |> (&("(\n" <> &1 <> "\n);\n")).()
    |> (&("CREATE TABLE IF NOT EXISTS#{name}\n" <> &1)).()
  end

  def create_indices_statement(object, opts) do
    # todo: add constraints
    ""
  end

  def insert_record_statment(data, opts) do
    table_name = opts[:name] || raise("table name required, got #{inspect(opts, pretty: true)}")
    column_list = data |> hd |> Map.keys() |> Enum.map(&to_string(&1)) |> Enum.join(", ")

    data
    |> Stream.map(fn record ->
      record
      |> Stream.map(fn
        {k, v} when is_bitstring(v) -> {k, String.replace(v, "'", "")}
        any -> any
      end)
      |> Stream.map(fn
        {_, nil} -> "NULL"
        {_, v} when is_bitstring(v) -> "'#{v}'"
        {_, v} when is_atom(v) -> "'#{to_string(v)}'"
        {_, v} -> v
      end)
    end)
    |> Stream.map(fn values -> "( " <> Enum.join(values, ", ") <> " )" end)
    |> Enum.join(",\n")
    |> (&(&1 <> ";\n")).()
    |> (&("INSERT INTO #{table_name}" <> "(#{column_list})" <> "\nVALUES\n" <> &1)).()
  end
end
