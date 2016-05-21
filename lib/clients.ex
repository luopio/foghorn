defmodule Clients do
  @moduledoc false

  use GenServer

  def start_link(_state, _opts) do
    IO.puts "Clients start_link"
    initial_state = %{clients: %{}}
    GenServer.start_link(__MODULE__, initial_state, [name: :clients])
  end

  def add_client(pid, tables) do
    GenServer.call(:clients, {:add, pid, tables})
  end

  def remove_client(pid) do
    GenServer.call(:clients, {:remove, pid})
  end

  def notify_clients_of(table, operation \\ nil, id \\ nil) do
    GenServer.cast(:clients, {:notify, {table, operation, id}})
  end

  def handle_call({:add, client_pid, tables}, _from, state) do
    new_clients = Enum.reduce(
      tables,
      state[:clients],
      fn table, acc ->
        unless Map.has_key?(acc, table) do
          Map.put(acc, table, [ client_pid | [] ])
        else
          Map.put(acc, table, [ client_pid | acc[table]] )
        end
      end
    )
    {:reply, new_clients, Map.put(state, :clients, new_clients)}
  end

  def handle_call({:remove, client_pid}, _from, state) do
    current_clients = state[:clients]
    new_clients = Enum.reduce(
      Map.keys(current_clients),
      %{},
      fn table, acc ->
        current_clients_for_table = current_clients[table]
        new_clients_for_table = Enum.filter(current_clients_for_table, fn pid -> pid != client_pid end)
        Map.put(acc, table, new_clients_for_table)
      end
    )
    {:reply, new_clients, Map.put(state, :clients, new_clients)}
  end

  def handle_cast({:notify, {table, operation, id}}, state) do
    IO.inspect(state)
    if state[:clients][table] do
      Enum.each(state[:clients][table], fn listener ->
          IO.puts "let's notify client PID"
          GenServer.cast(listener, {table, operation, id})
        end
      )
    end
    {:noreply, state}
  end

end