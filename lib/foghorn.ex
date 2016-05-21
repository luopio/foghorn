defmodule Foghorn do

  use GenServer

  @pg_conf [
     hostname: "192.168.99.100",
     port: 5432,
     username: "postgres",
     password: "postboy",
     database: "postgres" ]

  @channel "table_change"

  ## Interface functions >

  def start(_, _) do
    start_link
  end

  def start_link do
    GenServer.start_link(__MODULE__, {}, [name: :foggy])
  end

  def listen(listener, tables) do
    Enum.each tables, fn table -> GenServer.call(:triggers, {:add_trigger, table}) end
    Clients.add_client(listener, tables)
  end

  def stop_listening_for(listener) do
    Clients.remove_client(listener)
  end

  def add_trigger(table) do
    GenServer.call(:triggers, {:add_trigger, table})
  end

  def remove_trigger(table) do
    GenServer.call(:triggers, {:remove_trigger, table})
  end

  # foghorn.change(["users", "cows"], (id, tablename) => {})
  #   - save client for users and cows
  #   - ensure trigger to users and cows
  #   - on trigger notify the right clients

  ## < Interface functions

  def init(_) do
    IO.puts "Foghorn innnit"
    {:ok, _} = Notifications.start_link(%{pg_conf: @pg_conf, channel: @channel}, [name: :notifications])
    {:ok, _} = Triggers.start_link(%{pg_conf: @pg_conf}, [name: :triggers])
    {:ok, _} = Clients.start_link(%{}, [])
    {:ok, _} = HTTPServer.start()
    {:ok, {}}
  end

  def handle_info(event, state) do
    case event do
      {:notification, _pid, _ref, "table_change", payload} ->
        IO.puts("Foghorn: table_change: #{payload}")

      _ ->
        IO.puts("Foghorn: something strange shows up: #{event} on state #{state}")
    end
    {:noreply, state}
  end

end
