defmodule Notifications do
  @moduledoc false

  use GenServer

  def start_link(state, opts) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(%{pg_conf: pg_conf, channel: channel}) do
    IO.puts "Notifications init"
    {pid, ref} =
      if pg_conf[:hostname] != "__test__" do
        {:ok, pid} = Postgrex.Notifications.start_link(pg_conf)
        {:ok, ref} = Postgrex.Notifications.listen(pid, channel)
        {pid, ref}
      else
        {nil, nil}
      end
    schedule_reconnect()
    {:ok, {pid, channel, ref}}
  end

  def handle_info({:notification, _pid, _ref, _channel, payload}, state) do
    [_, tablename, operation, json] = Regex.run(~r/(.*),(.*),({.*})/, payload)
    Clients.notify_clients_of(tablename, operation, json)
    {:noreply, state}
  end

  def handle_info(:reconnect, {pid, channel, ref}) do
    IO.puts "notifications reconnect on #{DateTime.utc_now |> DateTime.to_iso8601}"
    IO.puts "pid alive? #{inspect Process.alive? pid}"
    IO.puts "ref is what? #{inspect ref}"
    {:ok, ref} =
      if pid do
        Postgrex.Notifications.unlisten(pid, ref)
        Postgrex.Notifications.listen(pid, channel)
      end
    IO.puts "ref is now #{inspect ref}"
    schedule_reconnect()
    {:noreply, {pid, channel, ref}}
  end

  def handle_info(event, state) do
    IO.puts("!!! Notifications.handle_info something strange shows up: #{event} on state #{state}")
    {:noreply, state}
  end

  def schedule_reconnect() do
    Process.send_after(self(), :reconnect, 5 * 60 * 1000)
  end

  #  def handle_call(_msg, _from, state) do
  #    {:reply, :ok, state}
  #  end
  #
  #  def handle_cast(_msg, state) do
  #    {:noreply, state}
  #  end
end