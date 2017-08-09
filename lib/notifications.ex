defmodule Notifications do
  @moduledoc false
  
  use GenServer

  def start_link(state, opts) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(%{pg_conf: pg_conf, channel: channel}) do
    IO.puts "Notifications init"
    {:ok, pid} = Postgrex.Notifications.start_link(pg_conf)
    {:ok, ref} = Postgrex.Notifications.listen(pid, channel)
    {:ok, {pid, channel, ref}}
  end

  def handle_info(event, state) do
    case event do
      {:notification, _pid, _ref, _channel, payload} ->
        [_, tablename, operation, json] = Regex.run(~r/(.*),(.*),({.*})/, payload)
        # IO.puts("Notifications.handle_info sees table change #{tablename} #{operation}")
        Clients.notify_clients_of(tablename, operation, json)
      _ ->
        IO.puts("!!! Notifications.handle_info something strange shows up: #{event} on state #{state}")
    end
    {:noreply, state}
  end

#  def handle_call(_msg, _from, state) do
#    {:reply, :ok, state}
#  end
#
#  def handle_cast(_msg, state) do
#    {:noreply, state}
#  end
end