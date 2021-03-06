defmodule Foghorn do
  use GenServer
  require Logger
  @channel "table_change"

  ## Interface functions >

  def start(_, _) do
    Logger.info("Foghorn starting")
    Logger.debug("WITH DEBUG")
    start_link()
  end

  def start_link do
    GenServer.start_link(__MODULE__, {}, name: :foggy)
  end

  ## < Interface functions
  def main(x) do
    init(x)
  end

  def init(_) do
    Logger.debug("Foghorn.init()")
    [app_conf, pg_conf_list] = find_configuration()
    :ok = Triggers.add_triggers(%{pg_conf: pg_conf_list, app_conf: app_conf})

    {:ok, _} =
      Notifications.start_link(%{pg_conf: pg_conf_list, channel: @channel}, name: :notifications)

    {:ok, _} = Clients.start_link(%{app_conf: app_conf}, [])
    {:ok, _} = HTTPServer.start()
    {:ok, %{pg_conf: pg_conf_list, app_conf: app_conf}}
  end

  def terminate(_reason, state) do
    Logger.info("Foghorn.terminate()")
    Triggers.remove_all_foghorn_triggers(state)
  end

  def find_configuration() do
    app_conf = read_conf_from_yaml()
    pg_conf = extract_postgres_connection_config(app_conf)
    pg_conf_env = read_pg_conf_from_env()

    pg_conf =
      if pg_conf_env do
        pg_conf_env |> Enum.into(pg_conf)
      else
        pg_conf
      end

    pg_conf_list = Map.to_list(pg_conf)
    Logger.debug("Postgres configuration")
    Logger.debug(pg_conf_list)
    [app_conf, pg_conf_list]
  end

  #######################
  ##  PRIVATE PARTS
  #######################

  defp read_pg_conf_from_env do
    regex =
      ~r/(?<db_type>\w+):\/\/(?<username>.+):(?<password>.+)@(?<host>[\w.]+)(:(?<port>.*))?\/(?<database>.+)/iu

    db_url = System.get_env("FOGHORN_DB")

    if db_url do
      IO.puts(".. reading configuration from url: #{db_url}")

      if db_url == nil || String.length(db_url) == 0 do
        Logger.error("Please define the environment variable FOGHORN_DB to point out the database to use. E.g. FOGHORN_DB=postgres://user:pass@host:port/database foghorn")
        exit(:shutdown)
      end

      captures = Regex.named_captures(regex, db_url)

      %{
        hostname: captures["host"],
        port:
          if(String.trim(captures["port"]) == "",
            do: 5432,
            else: elem(Integer.parse(captures["port"]), 0)
          ),
        username: captures["username"],
        password: captures["password"],
        database: captures["database"]
      }
    else
      nil
    end
  end

  defp read_conf_from_yaml do
    yaml_path = System.get_env("FOGHORN_CONFIG")

    if yaml_path == nil do
      Logger.error("No config file specified. Please set FOGHORN_CONFIG to a local path to the configuration.")
      exit(:shutdown)
    end

    IO.puts("Reading configuration from #{yaml_path}")
    {:ok, config} = YamlElixir.read_from_file(yaml_path)
    #    IO.puts "------------8<---------------"
    #    IO.inspect config
    #    IO.puts "------------>8---------------"
    config
  end

  defp extract_postgres_connection_config(app_conf) do
    Logger.debug(inspect(app_conf))
    %{
      hostname: app_conf["database"]["host"],
      port: app_conf["database"]["port"],
      username: app_conf["database"]["user"],
      password: app_conf["database"]["password"],
      database: app_conf["database"]["database"]
    }
  end
end
