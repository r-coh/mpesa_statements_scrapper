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
