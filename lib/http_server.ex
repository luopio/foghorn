defmodule HTTPServer do
  @moduledoc false

#  def start(_type, _args) do
  def start do
    IO.puts "HTTP server start"
    dispatch = :cowboy_router.compile([
      {:_,
        [
          {"/", :cowboy_static, {:priv_file, :foghorn, "index.html"}},
          {"/assets/[...]", :cowboy_static, {:priv_dir,  :foghorn, "assets"}},
          {"/ws", Websockets, []}
        ]
      }
    ])
    { :ok, _ } = :cowboy.start_http(:http,
                                        100,
                                       [{:port, 5555}, {:backlog, 2048}, {:max_connections, :infinity}],
                                       [{:env, [{:dispatch, dispatch}]}, {:timeout, :infinity}]
                                       )
  end

end