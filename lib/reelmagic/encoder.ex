defmodule Reelmagic.Encoder do
  require Logger

  defstruct queue: nil, recoding: false, waiter: nil

  def start_link(),
    do:
      Agent.start_link(
        fn ->
          %__MODULE__{queue: :queue.new()}
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

    skip =
      if File.exists?(to) do
        if File.exists?(from) do
          Logger.debug("'#{to}' already exists, removing")
          File.rm!(to)
          false
        else
          Logger.debug("'#{to}' already recoded, skipping")
          true
        end
      else
        false
      end

    if !skip do
      Logger.debug("recoding '#{from} to '#{to}")

      %{status: 0} =
        Porcelain.exec(
          "mencoder",
          [
            from,
            "-idx",
            "-oac",
            "lavc",
            "-ovc",
            "x264",
            "-x264encopts",
            "threads=4",
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
          ]
        )

      Logger.debug("finished recoding to '#{to}'")

      Logger.debug("removing #{from}")
      File.rm!(from)
    end

    Agent.update(__MODULE__, fn state -> %{state | recoding: false} end)

    check_queue()
  end

  def to(from), do: "#{Path.rootname(from)}.mp4"
end
