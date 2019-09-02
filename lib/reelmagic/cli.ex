defmodule Reelmagic.CLI do
  require Logger

  @moduledoc """
  Usage: `reelmagic_dl.ex --playlist 78hpp7h24y --to 'Focus on Rings' --concurrency 3

  Options:

    --help -h -- show this help
    --playlist -p [string] -- required, Wistia playlist ID
    --to -t [path] -- required, directory to save videos into
    --concurrency -c [int] -- optional, number of videos to be downloaded simultaneously, default 3
    --no-recode -- optional, don't recode, just download videos
    --ffmpeg or --mencoder -- choose one of mencoder (with x264 & ac3) or ffmpeg (with xvid & ac3), default is ffmpeg
  """

  @default_concurrency 3

  def main(argv) do
    argv
    |> parse_args
    |> process
  end

  def parse_args(argv) do
    {parsed, _rest, invalid} =
      OptionParser.parse(
        argv,
        switches: [
          help: :boolean,
          playlist: :string,
          to: :string,
          concurrency: :integer,
          recode: :boolean,
          mencoder: :boolean,
          ffmpeg: :boolean
        ],
        aliases: [h: :help, p: :playlist, t: :to, c: :concurrency, r: :recode]
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
        |> Keyword.put_new(:concurrency, @default_concurrency)
        |> Keyword.put_new(:recode, true)
        |> Keyword.put(:ffmpeg, !parsed[:mencoder])
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
