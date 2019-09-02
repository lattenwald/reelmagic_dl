defmodule Reelmagic.Encoder do
  require Logger

  defstruct queue: nil, recoding: false, waiter: nil, encoder: nil, keep_original: false

  def start_link(encoder, keep_original \\ false),
    do:
      Agent.start_link(
        fn ->
          %__MODULE__{queue: :queue.new(), encoder: encoder, keep_original: keep_original}
        end,
        name: __MODULE__
      )

  def set_waiter(waiter) do
    Logger.debug("setting waiter to #{inspect(waiter)}")
    Agent.update(__MODULE__, &%{&1 | waiter: waiter})
    check_queue()
  end

  def recode(from) do
    Agent.update(
      __MODULE__,
      fn state = %{queue: queue} -> %{state | queue: :queue.in(from, queue)} end
    )

    check_queue()
  end

  def check_queue() do
    Logger.debug("checking recoding queue: #{inspect(Agent.get(__MODULE__, & &1))}")

    to_recode =
      Agent.get_and_update(
        __MODULE__,
        fn
          state = %{recoding: true} ->
            {nil, state}

          state = %{queue: queue, waiter: waiter} ->
            case :queue.out(queue) do
              {{:value, val}, new_queue} ->
                {val, %{state | queue: new_queue, recoding: true}}

              {:empty, _} ->
                Logger.debug("waiter: #{inspect(waiter)}")

                case waiter do
                  nil ->
                    :ok

                  _ ->
                    Logger.debug("notifying #{inspect(waiter)} that we are :done")
                    send(waiter, :done)
                end

                {nil, state}
            end
        end
      )

    case to_recode do
      nil -> :ok
      fname -> recode!(fname)
    end
  end

  def recode!(from) do
    to = to(from)
    tmp = tmp(from)
    {encoder, keep} = Agent.get(__MODULE__, fn %{encoder: e, keep_original: k} -> {e, k} end)

    File.exists? to do
      Logger.debug("'#{to}' already recoded, skipping")
    else
      Logger.debug("recoding '#{from} to '#{to}")

      case File.rm(tmp) do
        :ok -> :ok
        {:error, :enoent} -> :ok
        other -> raise "Error removing temporary file '#{tmp}': #{inspect(other)}"
      end

      {cmd, args} = apply(__MODULE__, encoder, [from, tmp])
      %{status: 0} = Porcelain.exec(cmd, args)
      File.rename!(tmp, to)
      Logger.debug("finished recoding to '#{to}'")

      if !keep do
        Logger.debug("removing #{from}")
        File.rm!(from)
      end
    end

    Agent.update(__MODULE__, fn state -> %{state | recoding: false} end)

    check_queue()
  end

  def to(from), do: "#{Path.rootname(from)}.mp4"
  def tmp(from), do: "#{Path.rootname(from)}.tmp.mp4"

  def mencoder(from, to) do
    {"mencoder",
     [
       from,
       "-idx",
       "-oac",
       "lavc",
       "-ovc",
       "x264",
       "-x264encopts",
       "threads=4:log=0",
       "-lavcopts",
       "acodec=ac3",
       "-vf",
       "scale=-2:720",
       "-of",
       "lavf",
       "-lavfopts",
       "format=mpg",
       "-o",
       to
     ]}
  end

  def ffmpeg(from, to) do
    {"ffmpeg",
     [
       "-i",
       from,
       "-vcodec",
       "libxvid",
       "-acodec",
       "ac3",
       "-async",
       "1",
       "-vf",
       "scale=1280:-2",
       to
     ]}
  end
end
