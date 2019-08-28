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
      |> String.replace(~r{[^a-z0-9 _-]}ui, "_", global: true)

    prefix = String.pad_leading("#{n}", 2, "0")
    dest = "#{prefix} #{dest}#{extension}"

    recoded = Reelmagic.Encoder.to(dest)

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
        File.exists?(recoded)
      end

    if file_exists do
      Logger.debug("file already exists, skipping")
      {:ok, dest}
    else
      Logger.debug("downloading #{inspect(v)} to #{dest}")

      calculated_size = download!(url, dest, fn _ -> :ok end, expected_size)
      %{size: file_size} = File.stat!(dest)

      if file_size == calculated_size and calculated_size == expected_size do
        {:ok, dest}
      else
        File.rm!(dest)

        Logger.warn(
          "Downloading #{inspect(v)}, got calculated size #{calculated_size}, file size #{
            file_size
          }"
        )

        {:error, :invalid_size}
      end
    end
  end

  def download!(url, fname, callback, expected_size, range_from \\ 0) do
    headers =
      case range_from do
        0 -> []
        bytes -> [{"Range", "bytes=#{bytes}-"}]
      end

    begin_download = fn ->
      Logger.debug("begin_download '#{fname}' from #{range_from}")

      case :hackney.get(url, headers, "") do
        {:ok, code, _headers, client} when code == 200 or code == 206 ->
          {client, range_from}

        other ->
          raise(other)
      end
    end

    continue_download = fn acc = {client, bytes_downloaded} ->
      # Logger.debug("continue_download #{bytes_downloaded}")

      :hackney.stream_body(client)
      |> case do
        {:ok, data} ->
          if is_function(callback), do: callback.(data)
          {[data], {client, bytes_downloaded + byte_size(data)}}

        :done ->
          {:halt, acc}

        {:error, :timeout} ->
          case :hackney.get(url, [{"Range", "bytes=#{bytes_downloaded}-"}], "") do
            {:ok, 206, _headers, client} ->
              Logger.debug("restarted download '#{fname}' from #{bytes_downloaded}")
              {[], {client, bytes_downloaded}}

            other ->
              raise(other)
          end

        {:error, reason} ->
          raise "#{inspect(reason)}"
      end
    end

    finish_download = fn
      {_client, downloaded} ->
        Logger.debug("finish_download '#{fname}', downloaded #{downloaded} bytes")

        case downloaded do
          ^expected_size -> :ok
          other -> raise("'#{fname}': expected #{expected_size}, got #{other}")
        end

      other ->
        Logger.error("finish_download '#{fname}' called with #{inspect(other)}")
        raise inspect(other)
    end

    Path.dirname(fname) |> File.mkdir_p!()

    Logger.debug("downloading #{url}\n to #{fname}")

    downloaded =
      Stream.resource(
        begin_download,
        continue_download,
        finish_download
      )
      |> Stream.into(File.stream!(fname))
      |> Enum.reduce(0, &(&2 + byte_size(&1)))

    if downloaded < expected_size do
      download!(url, fname, callback, expected_size, downloaded)
    else
      downloaded
    end
  end
end
