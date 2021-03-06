# Foghorn

Watches your Postgres database for changes (using NOTIFY) and notifies listening clients through websockets (using Cowboy).

## Installation

### Run with docker

The easiest option. No local [Elixir](http://elixir-lang.org/) installation required, but you will need [Docker](https://www.docker.com/products/overview).

```
docker run -ti -v configfile.yaml:/config.yaml -p 5555:5555 --rm luopio/foghorn:latest start
```

### Run directly with Elixir

This requires a local [Elixir](http://elixir-lang.org/) installation.

```
FOGHORN_CONFIG="/path/to/config.yaml" mix run --no-halt
```

## Configuration

```yaml
# Define the database(s) to connect to
database:
  host: localhost
  port: 7654
  user: john
  password: doe
  database: my_database

# Listening directives. Each directive defines which db and which table to listen to.
# The payload defines what parameters to send to listening clients, where the key is
# used as the key shown to the client and value is the name of the database column where
# the value for clients is fetched
listen:
  general_post_change:
    table: posts
    # here clients will receive a payload of {id: <id value of changed row>, title: <title of changed row>}
    payload:
      id: id
      title: title

  comment_change_via_posts:
    table: post_comments
    # here clients will receive a payload of {id: <post_id>}
    payload:
      id: post_id

```

You can override the database connection with an environment variable. This will take precedence over the config
file:

```bash
FOGHORN_DB=postgres://user:pass@host:post/database FOGHORN_CONFIG="/path/to/config.yaml" mix run --no-halt
```

### Debugging

Set `FOGHORN_DEBUG=1` to receive debug level messages in console.

## Client javascript

A small javascript library is included to handle the client side communication. Include `Foghorn.es6` in your
application and use it like so:
```js
  // Set the address to your running Foghorn server
  Foghorn.ADDRESS = 'ws://localhost:5555/ws';

  // Signature here
  // Foghorn.listen(directiveNames: array<string>,
  //                notifyCallback: function(tablename, operation, id),
  //                (optional)connectedCallback: function(listenerId))
  Foghorn.listen(
    ['general_post_change', 'comment_change_via_posts'],
    function(directive, operation, payload) {
      console.log('Notified on', directive, 'of a', operation, 'with the payload', payload);
      console.log('Affected post carries the id', payload.id)
    });
```

## Test it

Open up a browser on [localhost:5555](localhost:5555). If you used Docker and/or Docker-machine
the host might be different.

## Running tests

Tests that work in isolation (no external database required):
```
$ FOGHORN_CONFIG=$(pwd)/test/test_isolation.yaml FOGHORN_DEBUG=1 mix test test/isolation_test.exs
```

Tests that do the whole roundtrip to the database and back:
```
$ FOGHORN_CONFIG=$(pwd)/test/test_postgres.yaml FOGHORN_DEBUG=1 mix test test/postgres_test.exs
```


## Compiling the Javascript code

The JS code is ES6 standard, thus it needs to be compiled to work on older browsers.
A precompiled file is available under [/priv/assets](./priv/assets/). Re-compilation requires Babel:

```
npm install
./compile_javascript.sh
```

## Things to do maybe

- Proper supervision tree
- Authentication scheme (via shared table in database?)
- Publish to Hex
- Multiple simultaneous databases -support
- Other databases? (PRs welcome)
- `mix test` to run all tests (set configuration on the fly)


License: MIT
