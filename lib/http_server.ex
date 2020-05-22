defmodule HTTPServer do
  @moduledoc false
  require Logger

  #  def start(_type, _args) do
  def start do
    Logger.debug("HTTPServer.start()")

    dispatch =
      :cowboy_router.compile([
        {:_,
         [
           {"/", :cowboy_static, {:priv_file, :foghorn, "index.html"}},
           {"/assets/[...]", :cowboy_static, {:priv_dir, :foghorn, "assets"}},
           {"/ws", Websockets, []}
         ]}
      ])

    {:ok, _} =
      :cowboy.start_clear(
        :foghorn_http,
        [{:port, 5555}, {:backlog, 2048}, {:max_connections, :infinity}],
        %{env: %{dispatch: dispatch}, timeout: :infinity}
      )
  end
end
