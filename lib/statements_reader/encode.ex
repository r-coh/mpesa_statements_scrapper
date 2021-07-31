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
