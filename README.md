# StatementsReader

Extract transactions from Mpesa Statement pdfs.
Extract to sql_tables, ets tables, csv, json.
Synthesis for preset metadata.

## Usage

To perform an export, make sure a couple of dependecies are installed.

1. `pdftotext` - installed with `pip install pdftotext`
2. `erlang` - make sure erlang is installed `sudo apt-get install esl-erlang`
3. `elixir` - installed with with `sudo apt-get install elixir`
   Visit https://www.erlang-solutions.com/downloads/ for the latest erlang/elixir version.

To build a commandline executable.

1. Fetch the dependecies `mix deps.get`
2. Build executable `mix escript.build`
3. A new executable named `xpesa_parser` should be available in the currect directory.

To install this executable to your system.

1. copy the executable to a directory in your `$PATH`
2. make sure the executable is executable `chmod +x xpesa_parser`

To extract mpesa statements

1. Download Mpesa Pdf statements, and add them to a folder.
2. Run the executable issuing password and path to the folder with mpesa statements
   `xpesa_parser <path to folder> -p password -o <path to output folder>`
3. The output folder will contain the extracted transactions, in json format(default) or in an SQL if specified with `--sql` option while riunning the executable.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `statements_reader` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:statements_reader, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/statements_reader](https://hexdocs.pm/statements_reader).
