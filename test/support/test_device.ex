defmodule Pluribus.VirtualDevices.TestDevice do
  @moduledoc """
  A simple test device implementation for testing purposes.
  Maintains a counter and records all commands received.
  """
  @behaviour Pluribus.VirtualDeviceState

  @impl true
  def init(device_id, opts) do
    initial_counter = Keyword.get(opts, :initial_counter, 0)

    {:ok,
     %{
       id: device_id,
       counter: initial_counter,
       commands_received: [],
       metadata: Keyword.get(opts, :metadata, %{})
     }}
  end

  @impl true
  def update_state(state) do
    {:ok, %{state | counter: state.counter + 1}}
  end

  @impl true
  def report_telemetry(state) do
    {:ok,
     %{
       device_id: state.id,
       counter: state.counter,
       timestamp: System.system_time(:millisecond),
       commands_count: length(state.commands_received)
     }}
  end

  @impl true
  def handle_command(command, state) do
    new_commands = [command | state.commands_received]
    new_state = %{state | commands_received: new_commands}

    case command do
      {:increment, amount} when is_integer(amount) ->
        new_counter = state.counter + amount
        {:reply, {:ok, new_counter}, %{new_state | counter: new_counter}}

      :get_commands ->
        {:reply, {:ok, state.commands_received}, new_state}

      :get_state ->
        {:reply, {:ok, state}, new_state}

      :reset ->
        {:noreply, %{new_state | counter: 0, commands_received: []}}

      {:set_metadata, metadata} ->
        {:noreply, %{new_state | metadata: metadata}}

      _ ->
        {:reply, {:error, :unknown_command}, state}
    end
  end
end
