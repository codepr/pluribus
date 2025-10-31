defmodule Pluribus.TelemetryAggregator do
  @moduledoc """

  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  # ---- GENSERVER CALLBACKS ----

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  def push_telemetry(telemetry) do
    IO.puts("Received #{inspect(telemetry)}")
  end
end
