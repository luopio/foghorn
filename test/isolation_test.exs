defmodule IsolationTest do

  use ExUnit.Case
  doctest Foghorn

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "pingpongs work" do
    socket = socket_connection()
    socket |> socket_send("PING")
    assert "PONG" == socket |> socket_recv

    socket2 = socket_connection()
    socket2 |> socket_send("PING")
    assert "PONG" == socket2 |> socket_recv

    socket |> socket_send("PING")
    assert "PONG" == socket |> socket_recv

    socket2 |> socket_send("PING")
    assert "PONG" == socket2 |> socket_recv
  end

  test "listening works" do
    socket = socket_connection()
    socket |> socket_send(Poison.encode!(%{op: "LISTEN", client_id: nil, request_id: "1", directives: ["testing_change"]}))
    %{"status" => "ok"} = socket |> socket_recv
    Clients.notify_clients_of("test_table", "INSERT", Poison.encode!%{id: 1})
    ret = socket |> socket_recv
    assert ret["directive"] == "testing_change"
  end

  test "multiple listeners work" do
    sockets = []
    for _ <- 1..10 do
      sockets = [socket_connection() | sockets]
      hd(sockets) |> socket_send(Poison.encode!(%{op: "LISTEN", client_id: nil, request_id: "1", directives: ["testing_change"]}))
    end
    Clients.notify_clients_of("test_table", "INSERT", Poison.encode!%{id: 1})

    for socket <- sockets do
      %{"directive" => "testing_change"} = socket |> socket_recv
    end
  end

  test "reconnecting works" do
    socket = socket_connection()
    socket |> socket_send(Poison.encode!(%{op: "LISTEN", client_id: nil, request_id: "1", directives: ["testing_change"]}))
    %{"status" => "ok", "client_id" => client_id} = socket |> socket_recv
    Socket.Web.close(socket)
    IO.puts "attempt to reconnect #{client_id}"
    socket_new = socket_connection()
    socket_new |> socket_send(Poison.encode!(%{op: "RECONNECT", client_id: client_id}))
    ret = socket_new |> socket_recv
    assert ret["client_id"] == client_id

    Clients.notify_clients_of("test_table", "INSERT", Poison.encode!%{id: 1})
    ret = socket_new |> socket_recv
    IO.inspect ret
    assert ret["op"] == "INSERT"
    assert ret["directive"] == "testing_change"
  end

  def socket_connection do
    Socket.Web.connect! "localhost", 5555, path: "/ws"
  end

  def socket_send(socket, msg) do
    Socket.Web.send! socket, {:text, msg}
  end

  def socket_recv(socket) do
    {:text, ret} = socket |> Socket.Web.recv!
    if String.starts_with?(ret, "{") do
      Poison.decode! ret
    else
      ret
    end
  end

end
