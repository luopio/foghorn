require IEx;

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
    IO.puts "Clients ready with directives to tables: #{inspect(tables_directives)}"
    initial_state = %{clients: %{}, app_conf: state[:app_conf], client_running_number: 0, tables_directives: tables_directives}
    GenServer.start_link(__MODULE__, initial_state, [name: :clients])
  end

  def add_client(client_id, pid, directives) do
    IO.puts "add client"
    GenServer.call(:clients, {:add, client_id, pid, directives})
  end

  def reconnect_client(pid, client_id) do
    GenServer.call(:clients, {:reconnect, pid, client_id})
  end

  def empty_tables do
    GenServer.call(:clients, {:get_empty_tables})
  end

  def remove_client(_pid, client_number) do
    GenServer.call(:clients, {:remove, client_number})
  end

  def notify_clients_of(table, operation \\ nil, json \\ nil) do
    GenServer.cast(:clients, {:notify, {table, operation, json}})
  end

  def handle_call({:add, client_id, client_pid, directive_names}, _from, state) do
    client_number = if !client_id do
      state[:client_running_number] + 1
    else
      client_id
    end
    IO.puts "---------- client add here. this will be for our new guest #{client_number}"
    new_clients = Enum.reduce(
      directive_names,
      state[:clients],
      fn directive, acc ->
        unless Map.has_key?(state[:app_conf]["listen"], directive) do
          IO.puts "(W)    clients: Unknown directive #{directive}, silently ignoring"
          acc
        else
          tail = acc[directive] || []
          Map.put(acc, directive, [ {client_number, client_pid, %{}} | tail] )
        end
      end
    )
    IO.puts "new listeners: #{inspect new_clients}"
    {:reply, client_number, Map.merge(state, %{clients: new_clients,
      client_running_number: client_number})}
  end

  def handle_call({:reconnect, new_pid, client_id}, _from, state) do
    IO.puts "clients reconnect with #{inspect(client_id)} (#{inspect(new_pid)})"
    new_clients = Enum.reduce(
      state[:clients],
      %{},
      fn({directive, clients}, acc) ->
        Map.put(acc, directive, Enum.map(
          clients,
          fn({c_num, c_pid, opts}) ->
            if c_num == client_id do
              {client_id, new_pid, opts}
            else
              {c_num, c_pid, opts}
            end
          end
        ))
      end
    )

    {:reply, client_id, Map.merge(state, %{clients: new_clients})}
  end

  #
  # Remove a client based on the ID number given from a call to Clients.add_client
  # restrict to only the PIDs that created it
  #
  def handle_call({:remove, client_number}, _from, state) do
    IO.puts "clients remove notifications from client id #{client_number}"
    new_clients = Enum.reduce(
      state[:clients],
      %{},
      fn {table, clients}, acc ->
        new_clients_for_table = Enum.filter(
          clients,
          fn {mnum, _mpid, _opts} -> mnum != client_number end
        )
        Map.put(acc, table, new_clients_for_table)
      end
    )
    {:reply, client_number, Map.put(state, :clients, new_clients)}
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
    updated_clients_per_directive =
      for directive_name <- directive_names, into: %{} do
        directive = state[:app_conf]["listen"][directive_name]
        payload = form_payload(directive, all_attributes)
        new_clients =
          if Map.get(state[:clients], directive_name) do
            Enum.reduce(
              state[:clients][directive_name],
              [],
              fn {num, pid, opts}, acc ->
                IO.puts "clients notify: client ##{inspect(num)} #{inspect(pid)} on directive #{directive_name}. Payload: #{inspect(payload)}"
                updated_client =
                  if Process.alive? pid do
                    GenServer.cast(pid, {directive_name, operation, payload})
                    opts = Map.put(opts, :last_seen_alive, DateTime.utc_now |> DateTime.to_unix)
                    {num, pid, opts}
                  else
                    now = DateTime.utc_now |> DateTime.to_unix
                    if not Map.has_key?(opts, :last_seen_alive) || now - Map.get(opts, :last_seen_alive) > 10 do
                      IO.puts "cleaning out PID #{inspect pid}"
                      {num, nil, opts}
                    else
                      {num, pid, opts}
                    end
                  end
                [updated_client | acc]
              end)
          else
            []
          end
        {directive_name, new_clients}
      end
    new_clients = clean_dropped_clients(state[:clients], updated_clients_per_directive)
    IO.puts "updated clients per directive from \n#{inspect state[:clients]} \nto \n#{inspect new_clients}"
    {:noreply, Map.put(state, :clients, new_clients)}
  end

  def clean_dropped_clients(clients, updated_clients) do
    for {directive_name, clients} <- clients, into: %{} do
      if Map.get(updated_clients, directive_name) do
        {
          directive_name,
          Enum.filter(updated_clients[directive_name], fn {_num, pid, _opts} -> pid != nil end)
        }
      else
        {directive_name, clients}
      end
    end
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