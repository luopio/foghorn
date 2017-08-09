defmodule Clients do
  @moduledoc false

  use GenServer

  def start_link(state, _opts) do
    IO.puts "Clients start_link"
    # form a lookup map of directives for a specific table
    tables_directives = Enum.reduce(
      state[:app_conf]["listen"],
      %{},
      fn {directive_name, directive}, acc ->
        # directive = state[:app_conf]["listen"][directive_name]
        unless Map.has_key?(acc, directive["table"]) do
          Map.put(acc, directive["table"], [directive_name])
        else
          directives_for_table = acc[directive["table"]]
          unless directive_name in directives_for_table do
            Map.put(acc, directive["table"], [directive_name | directives_for_table])
          end
        end
      end)

    initial_state = %{clients: %{}, app_conf: state[:app_conf], client_running_number: 0, tables_directives: tables_directives}
    GenServer.start_link(__MODULE__, initial_state, [name: :clients])
  end

  def add_client(pid, directives) do
    GenServer.call(:clients, {:add, pid, directives})
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

  def notify_clients_of(table, operation \\ nil, json \\ nil) do
    GenServer.cast(:clients, {:notify, {table, operation, json}})
  end

  def handle_call({:add, client_pid, directive_names}, _from, state) do
    client_number = state[:client_running_number] + 1
    new_clients = Enum.reduce(
      directive_names,
      state[:clients],
      fn directive, acc ->
        unless Map.has_key?(state[:app_conf]["listen"], directive) do
          IO.puts "(W)    Unknown directive #{directive}, silently ignoring"
          acc
        else
          unless Map.has_key?(acc, directive) do
            Map.put(acc, directive, [ {client_number, client_pid} | [] ])
          else
            Map.put(acc, directive, [ {client_number, client_pid} | acc[directive]] )
          end
        end
      end
    )
    {:reply, client_number, Map.merge(state, %{clients: new_clients,
      client_running_number: client_number})}
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
      fn {directive_name, clients}, acc ->
        new_clients_for_directive = Enum.filter(clients,
            fn {_mnum, mpid} -> mpid != pid end
          )
        Map.put(acc, directive_name, new_clients_for_directive)
      end
    )
    new_state = Map.put(state, :clients, new_clients)
    # IO.puts "after removal:"
    # IO.inspect new_state
    {:reply, pid, new_state}
  end

  def handle_call({:get_empty_tables}, _from, state) do
    empty_tables = state[:clients]
      |> Enum.filter(fn {_table, clients} -> length(clients) == 0 end)
      |> Enum.map(fn {table, _clients} -> table end)
    {:reply, empty_tables, state}
  end

  def handle_cast({:notify, {table, operation, payload_json}}, state) do
    directive_names = state[:tables_directives][table]
    {:ok, all_attributes} = Poison.decode(payload_json)
    for directive_name <- directive_names do
      directive = state[:app_conf]["listen"][directive_name]
      payload = form_payload(directive, all_attributes)
      if state[:clients][directive_name] do
        Enum.each(
          state[:clients][directive_name],
          fn {_num, pid} ->
            IO.puts "let's notify client PID #{inspect(pid)} on directive #{directive_name}. Payload: #{inspect(payload)}"
            GenServer.cast(pid, {directive_name, operation, payload})
          end)
      end
    end
    {:noreply, state}
  end

  def form_payload(directive, attrs) do
    Enum.reduce(
      directive["payload"],
      %{},
      fn {masked_name, wanted_payload}, acc ->
        Map.put(acc, masked_name, attrs[wanted_payload])
      end)
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

end