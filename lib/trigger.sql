-- Collection of SQL for testing purposes

CREATE OR REPLACE FUNCTION notify_posts_changes()
RETURNS trigger AS $$
DECLARE
  current_row RECORD;
BEGIN
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    current_row := NEW;
  ELSE
    current_row := OLD;
  END IF;
  PERFORM pg_notify(
    'posts_changes',
    json_build_object(
      'table', TG_TABLE_NAME,
      'type', TG_OP,
      'id', current_row.id,
      'data', row_to_json(current_row)
    )::text
  );
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notify_posts_changes_trg
AFTER INSERT OR UPDATE OR DELETE
ON posts
FOR EACH ROW
EXECUTE PROCEDURE notify_posts_changes();

-- These are the ones actually in use, but that should not be used directly:

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

CREATE TRIGGER notify_table_changed_trigger AFTER INSERT OR UPDATE OR DELETE ON users
FOR EACH ROW EXECUTE PROCEDURE notify_change_trigger();