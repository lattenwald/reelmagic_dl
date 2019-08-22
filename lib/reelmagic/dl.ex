defmodule Reelmagic.Dl do
  require Logger

  def videos(playlist) do
    url = "https://fast.wistia.net/embed/playlists/#{playlist}"
    %{status_code: 200, body: body} = HTTPoison.get!(url)

    regex = ~r{"medias":(\[(?:[^\[\]]*|(?1))*\])}
    [json_string] = Regex.run(regex, body, capture: :all_but_first)
    json = Jason.decode!(json_string)

    videos =
      Enum.map(json, fn entry ->
        name = entry["name"]

        asset =
          entry["embed_config"]["media"]["assets"]
          |> Enum.find(fn asset -> asset["type"] == "original" end)

        url = asset["url"]
        size = asset["size"]

        [name: name, url: url, size: size]
      end)

    1..length(videos)
    |> Enum.zip(videos)
    |> Enum.map(fn {n, v} -> Keyword.put(v, :n, n) end)
  end

  def download(v) do
    url = v[:url]
    name = v[:name]
    expected_size = v[:size]
    n = v[:n]

    extension = Path.extname(url)

    dest =
      name
      |> String.replace(":", "-", global: true)
      |> String.replace("\s+", " ", global: true)
      |> String.replace("[^\w\d_ -]", "_", global: true)

    prefix = String.pad_leading("#{n}", 2, "0")
    dest = "#{prefix} #{dest}#{extension}"

    file_exists =
      if File.exists?(dest) do
        %{size: file_size} = File.stat!(dest)

        if file_size == expected_size do
          true
        else
          Logger.debug("existing file has invalid size, removing")
          File.rm!(dest)
          false
        end
      else
        false
      end

    if file_exists do
      Logger.debug("file already exists, skipping")
      {:ok, dest}
    else
      Logger.debug("downloading #{inspect(v)} to #{dest}")

      calculated_size = download!(url, dest, fn _ -> :ok end)

      if calculated_size == expected_size do
        {:ok, dest}
      else
        File.rm!(dest)
        Logger.warn("Downloading #{inspect(v)}, got size #{calculated_size}")
        {:error, :invalid_size}
      end
    end
  end

  def download!(url, fname, callback) do
    begin_download = fn ->
      Logger.debug("begin_download")
      {:ok, 200, _headers, client} = :hackney.get(url, [], "")
      client
    end

    continue_download = fn client ->
      # Logger.debug "continue_download"
      :hackney.stream_body(client)
      |> case do
        {:ok, data} ->
          if is_function(callback), do: callback.(data)
          {[data], client}

        :done ->
          {:halt, client}

        {:error, reason} ->
          raise "#{inspect(reason)}"
      end
    end

    finish_download = fn _client ->
      Logger.debug("finish_download")
    end

    Path.dirname(fname) |> File.mkdir_p!()

    Logger.debug("downloading #{url}\n to #{fname}")

    Stream.resource(
      begin_download,
      continue_download,
      finish_download
    )
    |> Stream.into(File.stream!(fname))
    |> Enum.reduce(0, &(&2 + byte_size(&1)))
  end
end
