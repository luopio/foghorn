defmodule Foghorn do

  use GenServer

#  @pg_conf [
#     hostname: "192.168.99.100",
#     port: 5432,
#     username: "postgres",
#     password: "postboy",
#     database: "postgres" ]

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

  def unlisten(pid, client_id) do
    Clients.remove_client(pid, client_id)
    empty_tables = Clients.empty_tables
    Enum.each empty_tables, fn table -> remove_trigger(table) end
    client_id
  end

  def stop_listening_for(pid) do
    Clients.remove_clients_with_pid(pid)
    empty_tables = Clients.empty_tables
    Enum.each empty_tables, fn table -> remove_trigger(table) end
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

  def main(x) do
    init(x)
  end

  def init(_) do
    IO.puts "Foghorn innnit"
    pg_conf = read_pg_conf_from_env
    IO.inspect pg_conf
    {:ok, _} = Notifications.start_link(%{pg_conf: pg_conf, channel: @channel}, [name: :notifications])
    {:ok, _} = Triggers.start_link(%{pg_conf: pg_conf}, [name: :triggers])
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

  defp read_pg_conf_from_env do
    regex = ~r/(?<db_type>\w+):\/\/(?<username>.+):(?<password>.+)@(?<host>[\w.]+)(:(?<port>.*))?\/(?<database>.+)/iu
    db_url = System.get_env("FOGHORN_DB")
    if db_url do
      IO.puts ".. reading configuration from url: #{db_url}"
      if db_url == nil || String.length(db_url) == 0 do
        raise "Please define the environment variable FOGHORN_DB to point out the database to use. E.g. FOGHORN_DB=postgres://user:pass@host:port/database foghorn"
      end
      captures = Regex.named_captures(regex, db_url)
      [
         hostname: captures["host"],
         port: (if String.strip(captures["port"]) == "", do: 5432, else: elem(Integer.parse(captures["port"]), 0)),
         username: captures["username"],
         password: captures["password"],
         database: captures["database"]
      ]
    else
      IO.puts ".. reading configuration from separate variables"
      [
         hostname: System.get_env("FOGHORN_DB_HOST") || "localhost",
         port: elem(Integer.parse(System.get_env("FOGHORN_DB_PORT")), 0) || 5432,
         username: System.get_env("FOGHORN_DB_USER"),
         password: System.get_env("FOGHORN_DB_PASS"),
         database: System.get_env("FOGHORN_DB_NAME")
      ]
    end
  end


end
