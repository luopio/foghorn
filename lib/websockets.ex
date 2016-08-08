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

  #
  # Incoming messages are handled here
  #
  def websocket_handle({:text, command}, req, state) do
    IO.puts ">> websocket handling"
    IO.inspect command
    payload = Poison.decode!(command)
    IO.inspect payload
    # IO.inspect req
    # IO.inspect state
    ret_val = case payload do
        %{"op" => "STOP"} ->
          IO.puts "op stop!"
          Foghorn.stop_listening_for(self)
          %{status: "ok", table: "ALL", op: "STOP"}

        %{"op" => "UNLISTEN", "client_id" => remove_client_id} ->
          IO.puts "op unlisten"
          client_id = Foghorn.unlisten(self, remove_client_id)
          %{status: "ok", op: "UNLISTEN", client_id: client_id}

        %{"op" => "LISTEN", "request_id" => request_id, "table" => table} ->
          client_id = Foghorn.listen(self, [table])
          %{status: "ok", table: table, op: "LISTEN", client_id: client_id, request_id: request_id}

        _ ->
          IO.warn "Unknown fancy command: ", payload
          ret_val = %{status: "error", msg: "Unknown fancy command: " <> payload}
      end
    {:reply, {:text, Poison.encode!(ret_val)}, req, state}
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