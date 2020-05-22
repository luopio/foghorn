defmodule Websockets do
  @moduledoc false
  require Logger

  @behaviour :cowboy_websocket

  # def init({_tcp, _http}, _req, _opts) do
  #   Logger.debug("Websockets.init()")
  #   {:upgrade, :protocol, :cowboy_websocket}
  # end

  def init(req, state) do
     Logger.debug("Websockets.init 2 ()")
    {:cowboy_websocket, req, state}
  end

  def websocket_init(_state) do
    Logger.debug("Websockets.websocket_init 2 ()")
    state = %{}
    {:ok, state}
  end

  # def websocket_init(_transport_name, req, _opts) do
  #   Logger.debug("Websockets.websocket_init()")
  #   {:ok, req, :kikkeliskokkelis}
  # end

  def websocket_terminate(reason, _req, _state) do
    Logger.debug("Websockets terminate #{inspect(self())} #{inspect(reason)}")
    # we're assuming the client will reconnect shortly
    :ok
  end

  #
  # Incoming messages are handled here
  #
  def websocket_handle({:text, "PING"}, state) do
    Logger.debug("Websocket handling ping-pong")
    {:reply, {:text, "PONG"}, state}
  end

  def websocket_handle({:text, command}, state) do
    Logger.debug("Websocket_handle: #{inspect(command)}")
    case Poison.decode(command) do
      {:ok, payload} ->
        ret_val = case payload do
          %{"op" => "UNLISTEN", "client_id" => remove_client_id} ->
            client_id = Clients.remove_client(self(), remove_client_id)
            %{status: "ok", op: "UNLISTEN", client_id: client_id}

          %{"op" => "LISTEN", "request_id" => request_id, "directives" => directives, "client_id" => client_id} ->
            client_id = Clients.add_client(client_id, self(), directives)
            %{status: "ok", directives: directives, op: "LISTEN", client_id: client_id, request_id: request_id}

          %{"op" => "RECONNECT", "client_id" => client_id} ->
            client_id = Clients.reconnect_client(self(), client_id)
            %{status: "ok", op: "RECONNECT", client_id: client_id}

          _ ->
            IO.warn "Unknown fancy command: ", payload
            %{status: "error", msg: "Unknown fancy command: #{IO.inspect payload}"}
        end
        {:reply, {:text, Poison.encode!(ret_val)}, state}

      _ ->
        IO.puts ">> websocket_handle: Error reading payload: #{command}"
        {:reply, {:text, Poison.encode!(%{status: "error", message: "Don't know how to handle: #{command}"})}, state}
    end
  end

  def websocket_handle(data, state) do
    Logger.warn("Websocket handling something strange:")
    Logger.warn(inspect(data))
    {:ok, state}
  end

  # Sends the notification to the client
  def websocket_info({:"$gen_cast", {directive, operation, payload}}, state) do
    {:reply, {:text, Poison.encode!(%{directive: directive, op: operation, payload: payload})}, state}
  end

#  def websocket_handle({:binary, content}, req, state) do
#    {:reply, {:binary, content}, req, state}
#  end

end
