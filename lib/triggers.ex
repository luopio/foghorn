defmodule Triggers do
  @moduledoc false

  def add_triggers(%{pg_conf: pg_conf, app_conf: app_conf}) do
    pgc =
      if pg_conf[:hostname] != "__test__" do
        IO.puts "Adding triggers for tables"
        {:ok, pgc} = Postgrex.start_link(pg_conf)
        create_psql_notification_function(pgc)
        remove_all_foghorn_triggers(pgc)
        pgc
      end
    listen_directives = app_conf["listen"]
    for {listen_directive_name, listen_directive} <- listen_directives do
      add_trigger(listen_directive_name, listen_directive["table"], pgc)
    end
    :ok
  end

  def add_trigger(directive_name, table, pg_connection) do
    IO.puts "  +++ ADD trigger #{directive_name} to #{table}"
    query = """
      CREATE TRIGGER foghorn_#{directive_name} AFTER INSERT OR UPDATE OR DELETE ON #{table}
      FOR EACH ROW EXECUTE PROCEDURE notify_change_trigger();
    """
    if pg_connection do
      case Postgrex.query(pg_connection, query, []) do
        {:ok, _} -> IO.puts "    -> created trigger"
        {:error, %{postgres: %{code: :duplicate_object}}} ->
          IO.puts "    -> trigger already exists"
        {:error, reason} ->
          IO.puts "    !!!! Could not create trigger:"
          IO.inspect reason
      end
    else
      IO.puts "TESTING: would run the SQL #{inspect(query)}"
    end
  end

  def remove_all_foghorn_triggers(%{pg_conf: pg_conf}) do
    {:ok, pgc} = Postgrex.start_link(pg_conf)
    remove_all_foghorn_triggers(pgc)
  end

  def remove_all_foghorn_triggers(pg_connection) do
    IO.puts "  --- REMOVE all triggers"
    query = """
      DELETE FROM pg_trigger WHERE tgname LIKE 'foghorn_%'
    """
    Postgrex.query!(pg_connection, query, [])
  end

  defp create_psql_notification_function(pg_connection) do
    query = """
      CREATE OR REPLACE FUNCTION notify_change_trigger() RETURNS trigger AS $$
      DECLARE
        current_row RECORD;
      BEGIN
        IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
          current_row := NEW;
        ELSE
          current_row := OLD;
        END IF;
        -- PERFORM pg_notify('table_change', TG_TABLE_NAME || ',id,' || current_row.id );
        PERFORM pg_notify('table_change', TG_TABLE_NAME || ',' || TG_OP || ',' || row_to_json(current_row));
        RETURN new;
      END;
      $$ LANGUAGE plpgsql;
    """
    Postgrex.query!(pg_connection, query, [])
  end
end
