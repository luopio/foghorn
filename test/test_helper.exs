ExUnit.start()

defmodule Foghorn.TestHelpers do
  def socket_connection do
    Socket.Web.connect!("localhost", 5555, path: "/ws")
  end

  def socket_send(socket, msg) do
    Socket.Web.send!(socket, {:text, msg})
  end

  def socket_recv(socket) do
    {:text, ret} = socket |> Socket.Web.recv!()

    if String.starts_with?(ret, "{") do
      Poison.decode!(ret)
    else
      ret
    end
  end
end

