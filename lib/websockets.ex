defmodule Websockets do
  @moduledoc false
  @behaviour :cowboy_websocket_handler

  def init({tcp, http}, _req, _opts) do
    IO.puts ">> websockets init"
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_TransportName, req, _opts) do
    IO.puts ">> websockets websocket_init"
    {:ok, req, :kikkeliskokkelis}
  end

  def websocket_terminate(_reason, _req, _state) do
    IO.puts ">> websockets terminate"
    Foghorn.stop_listening_for(self)
    :ok
  end

  def websocket_handle({:text, tablename}, req, state) do
    IO.puts ">> websocket handling"
    IO.inspect tablename
#    IO.inspect req
#    IO.inspect state
    Foghorn.listen(self, [tablename])
    {:reply, {:text, Poison.encode!(%{status: "ok", table: tablename, op: "LISTEN"})}, req, state}
  end

  def websocket_handle(_data, req, state) do
    IO.puts ">> websocket handling something strange:"
    IO.inspect req
    {:ok, req, state}
  end

  # Sends the notification to the client
  def websocket_info({:"$gen_cast", {table, operation, id}}, req, state) do
    {:reply, {:text, Poison.encode!(%{table: table, op: operation, id: id})}, req, state}
  end

#  def websocket_handle({:binary, content}, req, state) do
#    {:reply, {:binary, content}, req, state}
#  end

end