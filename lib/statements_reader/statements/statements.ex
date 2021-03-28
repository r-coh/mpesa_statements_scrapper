defmodule StatementsReader.Statements do
  alias StatementsReader.Statement
  alias StatementsReader.Utils

  @password System.get_env("PDF_STATEMENT_PASSWORD", "password")

  def read_statement(path) do
    read_pdf = fn ->
      System.cmd(
        "pdftotext",
        ~w[-raw #{Path.basename(path)} -opw #{@password} -],
        cd: Path.dirname(path)
      )
    end

    read_pdf.()
    |> case do
      {pdf_as_text, _} ->
        pdf_as_text
        |> String.split("\n")
        |> (&CRUD.new(%{raw_data: &1})).()

      any ->
        raise("Failed to read file: #{path}\n#{any}")
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
end
