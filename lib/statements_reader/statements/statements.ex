defmodule StatementsReader.Statements do
  alias StatementsReader.Statement
  alias StatementsReader.Utils

  def read_statement(path, opts \\ []) do
    path
    |> Utils.read_pdf(opts)
    |> case do
      {:ok, raw_content} -> CRUD.new(%{raw_data: raw_content})
      {:error, err} -> raise(err)
    end
  end

  def parse_statement_info(%Statement{valid?: true, state: :new, raw_data: data} = statement) do
    stage_data = data |> Stream.drop(3) |> Stream.take(5) |> Enum.to_list()
    %{statement | info: stage_data, state: :info}
  end

  def parse_statement_summary(%Statement{valid?: true, raw_data: data} = statement) do
    stage_data = data |> Stream.drop(8) |> Enum.take(9)
    {header, tail} = Utils.parse_statement_summary_header(stage_data)
    summary = Enum.reduce(tail, [], &Utils.parse_statement_summary_info_record(&1, &2))
    %{statement | summary: {header, summary}, state: :summary}
  end

  def parse_statement_detail(%Statement{valid?: true, raw_data: data} = statement) do
    stage_data = data |> Stream.drop(17) |> Enum.to_list()
    header = stage_data |> Enum.take(3) |> Utils.parse_statement_detail_header()

    body =
      stage_data
      |> Enum.drop(3)
      |> Utils.fix_data()
      |> Utils.parse_statement_details_record()

    %{statement | data: {header, body}, state: :detail}
  end

  def prepare_info(%Statement{valid?: true, state: :cleaned, info: info} = statement) do
    info
    |> Enum.map(&Utils.split_and_match_info(&1))
    |> List.flatten()
    |> Map.new()
    |> (&%{statement | info: &1}).()
  end

  def prepare_summary(%Statement{valid?: true, state: :cleaned, summary: {hdr, data}} = statement) do
    hdr = Utils.header(hdr)

    data
    |> Stream.map(&Tuple.to_list(&1))
    |> Stream.map(&{hdr, &1})
    |> Enum.map(&Utils.map_detail(&1))
    |> (&%{statement | summary: &1}).()
  end

  def prepare_detail(%Statement{valid?: true, state: :cleaned, data: {hdr, data}} = statement) do
    hdr = Utils.header(hdr)

    data
    |> Stream.map(&Utils.fix_withdrawals(&1))
    |> Stream.map(&Tuple.to_list(&1))
    |> Stream.map(&{hdr, &1})
    |> Stream.map(&Utils.map_detail(&1))
    |> Enum.map(&Utils.parse_statement_detail_transaction_meta(&1))
    |> (&%{statement | data: &1}).()
  end

  def file_name(
        %Statement{
          info: %{
            end_date: endd,
            msisdn: msisdn,
            start_date: start,
            username: name
          }
        },
        opts \\ [format: :json]
      ) do
    String.replace(
      "#{name}_#{msisdn}mpesa_statements_#{start}-#{endd}.#{to_string(opts[:format])}",
      " ",
      "_"
    )
  end

  def export_statements(_statments, opts \\ [])

  def export_statements(
        %Statement{data: data, valid?: true, state: :formatted} = statement,
        opts
      ) do
    {:ok, data} = Utils.prepare_export_data(data, opts)
    opts = Keyword.put(opts, :filename, file_name(statement))
    file = Utils.prepare_file(opts)
    opts = Keyword.merge(opts, file: file)
    {Utils.write_to_file(data, opts), file}
  end

  def export_statements([%Statement{} | _] = statements, opts) do
    {:ok, data} =
      statements
      |> Enum.map(& &1.data)
      |> List.flatten()
      |> Utils.prepare_export_data(opts)

    time = System.monotonic_time(:millisecond) * -1
    filename = "mpesa_statement_export_#{time}.#{to_string(opts[:format])}"

    opts = Keyword.put(opts, :filename, filename)
    file = Utils.prepare_file(opts)
    opts = Keyword.merge(opts, file: file)
    {Utils.write_to_file(data, opts), file}
  end
end
