defmodule Reelmagic do
  require Logger

  def run(opts) do
    playlist = opts[:playlist]
    dir = opts[:to]
    concurrency = opts[:concurrency]
    recode = opts[:recode]
    keep_original = opts[:keep]

    encoder =
      cond do
        opts[:ffmpeg] -> :ffmpeg
        opts[:mencoder] -> :mencoder
        true -> raise "No encoder specified"
      end

    Reelmagic.Encoder.start_link(encoder, keep_original)

    if File.exists?(dir) do
      %{type: type} = File.stat!(dir)

      if type == :directory do
        input = IO.gets("Directory '#{dir}' already exists, continue? (Y/n)")

        cond do
          input == "\n" ->
            :ok

          Regex.match?(~r/^y/i, input) ->
            :ok

          true ->
            System.halt(0)
        end
      else
        IO.puts("Destination '#{dir}' already exists and it's not a directory")
        System.halt(1)
      end
    else
      File.mkdir_p!(dir)
    end

    File.cd!(dir)

    videos = Reelmagic.Dl.videos(playlist)

    videos
    |> Task.async_stream(
      fn v ->
        Reelmagic.Dl.download(v)
        |> case do
          {:ok, fname} ->
            Logger.debug("downloaded file #{fname}!")
            if recode, do: Reelmagic.Encoder.recode(fname)

          _other ->
            Logger.warn("failed downloading #{inspect(v)}")
        end
      end,
      max_concurrency: concurrency,
      timeout: :infinity
    )
    |> Stream.run()

    Reelmagic.Encoder.set_waiter(self())

    receive do
      :done -> :ok
    after
      1000 * 3600 * 5 ->
        "I waited long enough"
    end
  end
end
