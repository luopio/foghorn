defmodule Clients do
  @moduledoc false

  use GenServer

  def start_link(_state, _opts) do
    IO.puts "Clients start_link"
    initial_state = %{clients: %{}, client_running_number: 0}
    GenServer.start_link(__MODULE__, initial_state, [name: :clients])
  end

  def add_client(pid, tables) do
    GenServer.call(:clients, {:add, pid, tables})
  end

  def empty_tables do
    GenServer.call(:clients, {:get_empty_tables})
  end

  def remove_client(pid, client_number) do
    GenServer.call(:clients, {:remove, pid, client_number})
  end

  def remove_clients_with_pid(pid) do
    GenServer.call(:clients, {:remove_all, pid})
  end

  def notify_clients_of(table, operation \\ nil, id \\ nil) do
    GenServer.cast(:clients, {:notify, {table, operation, id}})
  end

  def handle_call({:add, client_pid, tables}, _from, state) do
    client_number = state[:client_running_number] + 1
    new_clients = Enum.reduce(
      tables,
      state[:clients],
      fn table, acc ->
        unless Map.has_key?(acc, table) do
          Map.put(acc, table, [ {client_number, client_pid} | [] ])
        else
          Map.put(acc, table, [ {client_number, client_pid} | acc[table]] )
        end
      end
    )
    {:reply, client_number, Map.merge(state, %{clients: new_clients, client_running_number: client_number})}
  end

  #
  # Remove a client based on the ID number given from a call to Clients.add_client
  # restrict to only the PIDs that created it
  #
  def handle_call({:remove, client_number, pid}, _from, state) do
    new_clients = Enum.reduce(
      state[:clients],
      %{},
      fn {table, clients}, acc ->
        new_clients_for_table = Enum.filter(clients,
            fn {mnum, mpid} -> mnum == client_number && mpid == pid end
          )
        Map.put(acc, table, new_clients_for_table)
      end
    )
    {:reply, client_number, Map.put(state, :clients, new_clients)}
  end

  def handle_call({:remove_all, pid}, _from, state) do
    new_clients = Enum.reduce(
      state[:clients],
      %{},
      fn {table, clients}, acc ->
        new_clients_for_table = Enum.filter(clients,
            fn {_mnum, mpid} -> mpid != pid end
          )
        Map.put(acc, table, new_clients_for_table)
      end
    )
    {:reply, pid, Map.put(state, :clients, new_clients)}
  end


  def handle_call({:get_empty_tables}, _from, state) do
      empty_tables = state[:clients]
        |> Enum.filter(fn {table, clients} -> length(clients) == 0 end)
        |> Enum.map(fn {table, clients} -> table end)
      {:reply, empty_tables, state}
    end


#  def handle_call({:remove, client_number, tables}, _from, state) do
#    current_clients = state[:clients]
#    new_clients = Enum.reduce(
#      Map.keys(current_clients),
#      %{},
#      fn table, acc ->
#        current_clients_for_table = current_clients[table]
#        if table in tables do
#          new_clients_for_table = Enum.filter(current_clients_for_table, fn {num, pid} -> num != client_number end)
#          Map.put(acc, table, new_clients_for_table)
#        else
#          Map.put(acc, table, current_clients_for_table)
#        end
#      end
#    )
#    {:reply, client_number, Map.put(state, :clients, new_clients)}
#  end


  def handle_cast({:notify, {table, operation, id}}, state) do
    IO.inspect(state)
    if state[:clients][table] do
      Enum.each(state[:clients][table], fn {num, pid} ->
          IO.puts "let's notify client PID"
          GenServer.cast(pid, {table, operation, id})
        end
      )
    end
    {:noreply, state}
  end

end