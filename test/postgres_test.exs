defmodule PostgresTest do
  use ExUnit.Case

  @setup_sql """
    CREATE TABLE
      foghorn_test_messages(id serial PRIMARY KEY, message VARCHAR(255) NOT NULL)
  """
  @clean_sql """
    DELETE FROM foghorn_test_messages;
  """

  setup do
    [app_conf, pg_conf] = Foghorn.find_configuration()
    {:ok, pid} = Postgrex.start_link(pg_conf)
    Postgrex.query(pid, @setup_sql, [])
    Postgrex.query!(pid, @clean_sql, [])
    {:ok, %{pid: pid}}
  end

  test "getting insert notifications", %{pid: pid} = _context do
    socket = start_listening()
    %{"status" => "ok"} = socket |> Foghorn.TestHelpers.socket_recv
    insert_to_database(pid)
    ret = socket |> Foghorn.TestHelpers.socket_recv

    assert %{
             "directive" => "test_simple_changes",
             "op" => "INSERT",
             "payload" => %{"msg" => "first message"}
           } = ret
  end

  test "getting update notifications", %{pid: pid} = _context do
    insert_to_database(pid)
    socket = start_listening()
    %{"status" => "ok"} = socket |> Foghorn.TestHelpers.socket_recv
    update_in_database(pid)
    ret = socket |> Foghorn.TestHelpers.socket_recv

    assert %{
             "directive" => "test_simple_changes",
             "op" => "UPDATE",
             "payload" => %{"msg" => "first message updated"}
           } = ret
  end

  defp start_listening do
    socket = Foghorn.TestHelpers.socket_connection()

    socket
    |> Foghorn.TestHelpers.socket_send(
      Poison.encode!(%{
        op: "LISTEN",
        client_id: nil,
        request_id: "1",
        directives: ["test_simple_changes"]
      })
    )

    socket
  end

  defp insert_to_database(pid) do
    Postgrex.query!(
      pid,
      "INSERT INTO foghorn_test_messages (message) VALUES ('first message')",
      []
    )
  end

  def update_in_database(pid) do
    Postgrex.query!(
      pid,
      "UPDATE foghorn_test_messages SET message='first message updated' WHERE message='first message'",
      []
    )
  end

end
