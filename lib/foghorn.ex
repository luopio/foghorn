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
    start_link()
  end

  def start_link do
    GenServer.start_link(__MODULE__, {}, [name: :foggy])
  end

  ## < Interface functions
  def main(x) do
    init(x)
  end

  def init(_) do
    IO.puts "Foghorn init"
    # pg_conf = read_pg_conf_from_env()
    app_conf = read_conf_from_yaml()
    hard_coded_db_name = "main"
    pg_conf = extract_postgres_connection_config app_conf, hard_coded_db_name
    :ok = Triggers.add_triggers(%{pg_conf: pg_conf, app_conf: app_conf, db_name: hard_coded_db_name})

    {:ok, _} = Notifications.start_link(%{pg_conf: pg_conf, channel: @channel}, [name: :notifications])
    {:ok, _} = Clients.start_link( %{app_conf: app_conf}, [])
    {:ok, _} = HTTPServer.start()
    {:ok, %{pg_conf: pg_conf, app_conf: app_conf, db_name: hard_coded_db_name}}
  end

  def terminate(_reason, state) do
    IO.puts "Foghorn terminating"
    Triggers.remove_all_foghorn_triggers(state)
  end


  #######################
  ##  PRIVATE PARTS
  #######################

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

  defp read_conf_from_yaml do
    yaml_path = System.get_env("FOGHORN_CONFIG") || "./config/default.yaml"
    IO.puts "Reading configuration from #{yaml_path}"
    config = YamlElixir.read_from_file(yaml_path)
#    IO.puts "------------8<---------------"
#    IO.inspect config
#    IO.puts "------------>8---------------"
    config
  end

  defp extract_postgres_connection_config(app_conf, db_name) do
      [
        hostname: app_conf["databases"][db_name]["host"],
        port:     app_conf["databases"][db_name]["port"],
        username: app_conf["databases"][db_name]["user"],
        password: app_conf["databases"][db_name]["password"],
        database: app_conf["databases"][db_name]["database"],
      ]
    end



end
