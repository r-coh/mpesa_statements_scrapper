defmodule StatementsReader.Utils do
  require Logger
  alias StatementsReader.Utils

  defp log_return(any, acc) do
    Logger.error(
      "[Error] matching, encountered line: \n\tGot: #{inspect(any, pretty: true)}\n\n\tAcc: #{inspect(acc, pretty: true)}"
    )

    acc
  end

  def split(list, acc \\ [])
  def split([], acc), do: acc
  def split([a, b | rest], acc), do: split(rest, acc ++ [[a, b]])

  def parse_statement_summary_header([entry | tail]) do
    header =
      entry
      |> String.split(" ")
      |> Utils.split()
      |> Enum.map(&Enum.join(&1, " "))
      |> Enum.reduce({}, fn k, acc -> Tuple.append(acc, k) end)

    {header, tail}
  end

  def parse_statement_summary_info_record(line, acc) do
    ~r/([A-Z\s:].+) ([0-9.,]+\.\d{2}) ([0-9.,]+\.\d{2})/
    |> Regex.run(line)
    |> case do
      [_, tt, pi, po] -> acc ++ [{tt, pi, po}]
      any -> log_return(any, acc)
    end
  end

  def parse_statement_detail_header([a, b, c]) do
    a_r = ~r/([A-Za-z\s]+)\. ([CTa-z\s]+) ([Da-z]+) ([Ta-z]+)/
    c_r = ~r/([IPa-z\s]+) ([Wa-z]+) ([Ba-z]+)/

    a =
      Regex.run(a_r, a)
      |> case do
        [_ | a] -> a
        any -> log_return(any, [])
      end

    c =
      Regex.run(c_r, c)
      |> case do
        [_ | c] -> c
        any -> log_return(any, [])
      end

    b = (a || []) |> List.last() |> (&[&1]).() |> Kernel.++([b]) |> Enum.join(" ")
    List.flatten([a, b, c]) -- ["Transaction"]
  end

  def parse_statement_details_record(data) do
    pattern =
      ~r/(\b[A-Z0-9]{10})\s(\d{4}\-\d{2}\-\d{2}\s\d{2}:\d{2}:\d{2})\s([A-Za-z0-9\s-].+)\s([Completed].+?)\s([0-9-,.]+)\s([0-9-,.]+)/

    parse = fn line ->
      pattern
      |> Regex.run(line)
      |> case do
        [_, tid, t, desc, ts, amt, bal] -> {tid, t, desc, ts, amt, bal}
        _ -> nil
      end
    end

    Enum.map(data, &parse.(&1))
  end

  def fix_data(data) do
    disclaimer? = fn
      line when is_bitstring(line) ->
        line
        |> String.split(" ")
        |> hd
        |> (&("Disclaimer:" == &1)).()
        |> if(do: :disclaimer, else: false)

      data when is_list(data) ->
        Enum.reduce(data, {false, []}, fn
          {:disclaimer, _}, {false, acc} -> {true, acc}
          {false, _}, {true, acc} -> {true, acc}
          {true, _} = i, {true, acc} -> {false, acc ++ [i]}
          any, {c, acc} -> {c, acc ++ [any]}
        end)
        |> (fn {_, data} -> data end).()
    end

    check_head = fn line ->
      r = ~r/(^[A-Z0-9]{10}$)/

      line
      |> String.split(" ")
      |> hd
      |> (&Regex.match?(r, &1)).()
      |> if(
        do: {true, line},
        else: {disclaimer?.(line), line}
      )
    end

    fix = fn
      {true, entry}, acc ->
        acc ++ [entry]

      {false, entry}, acc ->
        last = List.last(acc)
        entry = last <> " " <> entry
        (acc -- [last]) ++ [entry]

      {:disclaimer, _}, acc ->
        acc
    end

    fix_incomplete_txs = fn data ->
      data
      |> Enum.reduce([], fn i, acc ->
        n = i |> String.split(" ") |> length()

        cond do
          n > 5 -> acc ++ [i]
          true -> (acc -- [List.last(acc)]) ++ ["#{List.last(acc)} #{i}"]
        end
      end)
    end

    data
    |> Enum.map(&check_head.(&1))
    |> disclaimer?.()
    |> Enum.reduce([], &fix.(&1, &2))
    |> fix_incomplete_txs.()
  end

  def fix_withdrawals({_, _, _, _, "-" <> wd, bal} = rec) do
    {wd, _} = parse_amount(wd)
    {bal, _} = parse_amount(bal)

    rec
    |> Tuple.delete_at(4)
    |> Tuple.delete_at(4)
    |> Tuple.append(nil)
    |> Tuple.append(wd)
    |> Tuple.append(bal)
  end

  def fix_withdrawals({_, _, _, _, pd, bal} = rec) do
    {pd, _} = parse_amount(pd)
    {bal, _} = parse_amount(bal)

    rec
    |> Tuple.delete_at(4)
    |> Tuple.delete_at(4)
    |> Tuple.append(pd)
    |> Tuple.append(nil)
    |> Tuple.append(bal)
  end

  def parse_statement_detail_transaction_meta(%{details: deet} = rec) do
    account_id = fn line ->
      ~r/to\s([A-Z0-9a-z]+)\s-|from\s([A-Z0-9a-z]+)\s-|At\sAgent\sTill\s([A-Z0-9a-z]+?)\s-|to\sunregistered\suser\s([0-9]+)|at\sAgent\sTill\s([0-9]+)\s-/
      |> Regex.run(line)
      |> case do
        [_ | account] -> List.last(account)
        _ -> nil
      end
    end

    account_name = fn line ->
      ~r/\-\s([A-Za-z0-9].+)|to\s(unregistered\suser)/
      |> Regex.run(line)
      |> case do
        [_, account] -> account
        _ -> nil
      end
    end

    description = fn line ->
      ~r/([A-Za-z\s]+?)\sto\s\d{1}|([A-Za-z\s]+?)\sfrom|([A-Za-z\s]+?)\sat\s\d{1}$|([A-Za-z\s]+?\sTill\s)|([A-Za-z\s]+?\sCharge)|\b([A-Za-z\s]+?\sPurchase){2}|([A-Za-z\s]+?\sBundles)|(Airtime\sPurchase)|(Transfer.+?)\sto/
      |> Regex.run(line)
      |> case do
        [_ | desc] -> List.last(desc)
        _ -> nil
      end
    end

    type = fn line ->
      ~r/(Payment)|\s(Purchase)|(Buy)|(Transfer)\sto|\b\s(Withdrawal)|(Deposit)|(received)|\s(Charge)|(Send).+!Charge|(Pay\sBill\s)Online|(Transfer)\sof\sfunds\sto|(Pay\sBill)\s[a-z]|\s(Reversal)\s|(OverDraft)\s|(Fuliza)\s|(M-Shwari)\s|(Loan\sRepayment)\s/
      |> Regex.run(line)
      |> case do
        [_ | type] ->
          type
          |> List.last()
          |> String.trim()
          |> String.replace(" ", "_")
          |> String.replace("-", "_")
          |> String.downcase()
          |> String.to_atom()

        _ ->
          nil
      end
    end

    params = %{
      account_id: account_id.(deet),
      account_name: account_name.(deet),
      description: description.(deet),
      type: type.(deet)
    }

    Map.merge(rec, params)
  end

  def parse_amount(amt), do: amt |> String.replace(",", "") |> Float.parse()
  def map_detail({keys, data}), do: keys |> Enum.zip(data) |> Map.new()

  def header(header) when is_tuple(header),
    do: header |> Tuple.to_list() |> header()

  def header(header),
    do:
      header
      |> Enum.map(&(&1 |> String.replace(" ", "_") |> String.downcase() |> String.to_atom()))

  def split_and_match_info(line) do
    user_name_r = ~r/(\b[A-Za-z]+?\s\b[A-Za-z]+?)\s([A-Z]+\s[A-Z]+)/
    msisdn_r = ~r/(\b[A-Za-z]+?\s\b[A-Za-z]+?)\s([0-9]{10})/
    email_r = ~r/(\b[A-Za-z]+?\s\b[A-Za-z]+?)\s([a-z@.]+)/
    date_r = ~r/(\b[A-Za-z]+?\s\b[A-Za-z]+?\s\b[A-Za-z]+?)\s(\d{2}\s\b[A-Za-z]+\s\d{4})/

    s_r =
      ~r/(\b[A-Za-z]+?\s\b[A-Za-z]+?)\s(\d{2}\s\b[A-Za-z]+\s\d{4})\s-\s(\d{2}\s\b[A-Za-z]+\s\d{4})/

    cond do
      Regex.match?(user_name_r, line) ->
        user_name_r |> Regex.run(line) |> (fn [_, _, value] -> {:username, value} end).()

      Regex.match?(msisdn_r, line) ->
        msisdn_r |> Regex.run(line) |> (fn [_, _, value] -> {:msisdn, value} end).()

      Regex.match?(email_r, line) ->
        email_r |> Regex.run(line) |> (fn [_, _, value] -> {:email, value} end).()

      Regex.match?(date_r, line) ->
        date_r |> Regex.run(line) |> (fn [_, _, value] -> {:date, value} end).()

      Regex.match?(s_r, line) ->
        s_r
        |> Regex.run(line)
        |> (fn [_, _, start, fin] -> [{:start_date, start}, {:end_date, fin}] end).()

      true ->
        raise("failed to parse: #{line}")
    end
  end

  def check_path(path) when is_bitstring(path) do
    path = Path.expand(path)
    pdf? = Path.extname(path) == ".pdf"

    cond do
      File.dir?(path) -> {:dir, path}
      File.exists?(path) and pdf? -> {:file, path}
      true -> {:invalid, path}
    end
  end

  def filter_statements(path) do
    "ls"
    |> System.cmd(~w[#{path}])
    |> case do
      {data, 0} ->
        data
        |> String.split("\n")
        |> Stream.filter(&String.ends_with?(&1, ".pdf"))
        |> Enum.map(&(path <> "/" <> &1))

      {err, err_code} ->
        raise("Failed to filter files, encountered: code #{err_code}, \nError: #{err}")
    end
  end

  @password System.get_env("PDF_STATEMENT_PASSWORD")

  def read_pdf(path, opts \\ []) do
    password = opts[:password] || @password

    "pdftotext"
    |> System.cmd(
      ~w[-raw #{Path.basename(path)} -opw #{password} -],
      cd: Path.dirname(path)
    )
    |> case do
      {pdf_as_text, 0} ->
        pdf_as_text
        |> String.split("\n")
        |> (&{:ok, &1}).()

      any ->
        {:error, "Failed to read file: #{path}\n#{any}"}
    end
  end

  def prepare_export_data(data, opts \\ []) when is_list(data) do
    sql_opts = [name: "mpesa_statmenets_transactions", opts: [account_name: [:text]]]

    case opts[:format] do
      :sql -> {:ok, SQL.encode!(data, sql_opts)}
      :csv -> {:ok, CSV.encode!(data)}
      :xlsx -> {:ok, Excel.encode!(data)}
      _ -> {:ok, Jason.encode!(data)}
    end
  rescue
    any ->
      {:error, "Failed to encode data: #{inspect(any, pretty: true)}"}
  end

  def write_to_file(_data, opts \\ [])

  def write_to_file(%Elixlsx.Workbook{} = data, opts) do
    path = opts[:file]
    Elixlsx.write_to(data, path)
  end

  def write_to_file(data, opts) when is_bitstring(data) do
    path = opts[:file]
    File.write!(path, data)
  end

  def prepare_file(opts \\ [output: File.cwd!()]) do
    verify_dir = fn path ->
      path
      |> File.dir?()
      |> case do
        true -> path
        false -> path |> File.mkdir_p!() |> (fn _ -> path end).()
      end
    end

    verify_file = fn path ->
      path
      |> File.stat()
      |> case do
        {:ok, _} -> path
        {:error, :enoent} -> path |> File.touch!() |> (fn _ -> path end).()
      end
    end

    opts = if is_nil(opts[:output]), do: Keyword.put(opts, :output, File.cwd!()), else: opts

    opts[:output]
    |> Path.expand()
    |> Kernel.<>("/mpesa_statements_exports/")
    |> verify_dir.()
    |> Kernel.<>(
      "#{opts[:filename] || 'mpesa_statement_export_#{System.monotonic_time(:second) * -1}.json'}"
    )
    |> verify_file.()
  end
end
