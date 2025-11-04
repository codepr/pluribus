defmodule Pluribus.TelemetryAggregators.TestAggregator do
  @moduledoc """
  A test telemetry aggregator that stores telemetry in ETS for testing.
  Uses ETS instead of process dictionary to work across processes.
  """
  @behaviour Pluribus.TelemetryAggregator

  @table_name :test_telemetry_table

  def start_link do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:named_table, :public, :ordered_set])
        {:ok, self()}

      _ ->
        {:ok, self()}
    end
  end

  @impl true
  def publish_telemetry(telemetry) do
    ensure_table()
    timestamp = System.monotonic_time(:microsecond)
    :ets.insert(@table_name, {timestamp, telemetry})
    :ok
  end

  def get_telemetry do
    ensure_table()

    :ets.tab2list(@table_name)
    |> Enum.sort_by(fn {ts, _} -> ts end)
    |> Enum.map(fn {_, telemetry} -> telemetry end)
  end

  def clear_telemetry do
    ensure_table()
    :ets.delete_all_objects(@table_name)
    :ok
  end

  defp ensure_table do
    case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [:named_table, :public, :ordered_set])

      _ ->
        :ok
    end
  end
end
