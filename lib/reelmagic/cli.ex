defmodule Reelmagic.CLI do
  require Logger

  @moduledoc """
  Usage: `reelmagic_dl.ex --playlist 78hpp7h24y --to 'Focus on Rings'
  """

  def main(argv) do
    argv
    |> parse_args
    |> process
  end

  def parse_args(argv) do
    {parsed, _rest, invalid} =
      OptionParser.parse(
        argv,
        switches: [help: :boolean, playlist: :string, to: :string],
        aliases: [h: :help, p: :playlist, t: :to]
      )

    cond do
      length(invalid) > 0 ->
        {:invalid_opts, invalid}

      parsed[:help] ->
        :help

      !parsed[:playlist] ->
        :help

      !parsed[:to] ->
        :help

      true ->
        parsed
    end
  end

  def process(:help) do
    IO.puts(@moduledoc)
    System.halt(0)
  end

  def process(opts) do
    opts_str =
      opts
      |> Enum.map(fn {k, v} -> "--#{k} #{v}" end)
      |> Enum.join(" ")

    IO.puts("Running with options: #{opts_str}")

    Reelmagic.run(opts)
  end
end
