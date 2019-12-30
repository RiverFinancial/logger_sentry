defmodule LoggerSentry.Sentry do
  @moduledoc """
  Generate output and options for sentry.
  """

  @doc """
  Generate output.
  """
  @spec generate_output(atom, Keyword.t(), list()) :: {Exception.t(), Keyword.t()}
  def generate_output(level, metadata, message) do
    case Keyword.get(metadata, :crash_reason) do
      {reason, stacktrace} -> {reason, Keyword.put(metadata, :stacktrace, stacktrace)}
      _ -> generate_output_without_crash_reason(level, metadata, message)
    end
  end

  @doc false
  defp generate_output_without_crash_reason(level, metadata, message) do
    case Keyword.get(metadata, :exception) do
      nil ->
        {output, _} =
          Exception.blame(
            level,
            :erlang.iolist_to_binary(message),
            Keyword.get(metadata, :stacktrace, [])
          )

        {output, metadata}

      exception ->
        {exception, metadata}
    end
  end

  @doc """
  Generate options for sentry.
  """
  @spec generate_opts(Keyword.t(), list(), list(atom()) | :all) :: Keyword.t()
  def generate_opts(metadata, message, metadata_whitelist_keyss) do
    metadata
    |> generate_opts_extra(message, metadata_whitelist_keyss)
    |> generate_opts_fingerprints(message)
  end

  @doc false
  defp generate_opts_extra(metadata, msg, data_whitelist_keys) do
    case data_whitelist_keys do
      :all ->
        metadata
        |> Enum.filter(fn {_key, value} ->
          is_binary(value) || is_atom(value) || is_number(value)
        end)

      keys ->
        Enum.reduce(keys, [], fn key, acc ->
          case Keyword.fetch(metadata, key) do
            {:ok, val} -> [{key, val} | acc]
            :error -> acc
          end
        end)
    end
    |> Keyword.put(:log_message, :erlang.iolist_to_binary(msg))
    |> Map.new()
    |> Map.merge(Keyword.get(metadata, :extra, %{}))
    |> case do
      empty when empty == %{} -> metadata
      other -> Keyword.put(metadata, :extra, other)
    end
  end

  @doc false
  defp generate_opts_fingerprints(metadata, msg) do
    case generate_fingerprints(metadata, msg) do
      [] -> metadata
      other -> Keyword.put(metadata, :fingerprint, other)
    end
  end

  @doc false
  defp generate_fingerprints(metadata, msg) do
    :logger_sentry
    |> Application.get_env(:fingerprints_mods, [])
    |> LoggerSentry.Fingerprint.fingerprints(metadata, msg)
    |> Kernel.++(Keyword.get(metadata, :fingerprint, []))
    |> case do
      [] -> []
      tmp -> Enum.uniq(tmp)
    end
  end

  # __end_of_module__
end
