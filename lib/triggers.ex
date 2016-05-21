defmodule Triggers do
  @moduledoc false
  
  use GenServer

  def start_link(state, opts) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init(%{pg_conf: pg_conf}) do
    IO.puts "Triggers init"
    {:ok, pgc} = Postgrex.start_link(pg_conf)
    create_psql_notification_function(pgc)
    {:ok, %{pg_connection: pgc}}
  end

  def handle_call({:add_trigger, table}, _from, %{pg_connection: pgc} = state) do
    IO.puts "Triggers handling add_trigger for #{table}"
    add_trigger(table, pgc)
    # new_triggers = List.push(triggers, res)
    {:reply, :ok, state}
  end

  def handle_call({:remove_trigger, table}, _from, %{pg_connection: pgc} = state) do
    IO.puts "Triggers handling remove_trigger for #{table}"
    remove_trigger(table, pgc)
    {:reply, :ok, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def add_trigger(table, pg_connection) do
    IO.puts "ADD Trigger to #{table}"
    query = """
      CREATE TRIGGER notify_table_changed_trigger AFTER INSERT OR UPDATE OR DELETE ON #{table}
      FOR EACH ROW EXECUTE PROCEDURE notify_change_trigger();
    """
    IO.puts "ADD TRIGGER: #{query}"
    case Postgrex.query(pg_connection, query, []) do
      {:ok, _} -> IO.puts "created trigger"
      {:error, reason} ->
        IO.puts "could not create trigger:"
        IO.inspect reason
    end
  end

  def remove_trigger(table, pg_connection) do
    query = """
      DROP TRIGGER IF EXISTS notify_table_changed_trigger ON #{table}
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
        PERFORM pg_notify('table_change', TG_TABLE_NAME || ',' || TG_OP || ',' || current_row.id );
        RETURN new;
      END;
      $$ LANGUAGE plpgsql;
    """
    Postgrex.query!(pg_connection, query, [])
  end
end