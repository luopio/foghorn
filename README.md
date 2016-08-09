# Foghorn

Watches your database for changes and notifies listening clients through websockets.

I.e. you do this in your client javascript:
```js
  // Set the address to your running foghorn server. As we are on websockets,
  // no funky cross-domain settings are required.
  Foghorn.ADDRESS = 'ws://localhost:5555/ws';

  // Foghorn.listen(tableName:string,
  //                notifyCallback:function(tablename, operation, id),
  //                (optional)connectedCallback:function(listenerId))
  Foghorn.listen(
    'users',
    function(tablename, operation, id) {
      console.log('notified on', tablename, 'of a', operation, 'for the id:', id);
    });
```

If you want to gracefully stop listening later on you can store the listener ID,
which is given to you through `listen()` and close the connection:
```js
var myListenerId = null;
Foghorn.listen(
    'users',
    function notifyCallback(tablename, operation, id) { ; }
    function connectedCallback(listenerId) {
      myListenerId = listenerId;
    });

// then later in your code you call
myListenerId != null && Foghorn.unlisten(myListenerId);
```

## Supported databases

Postgres (via NOTIFY).

## Things to do
- Proper supervision tree
- Authentication scheme (via shared table in database?)
- Publish to Hex
- Limit tables that notifications can be placed on
- Multiple simultaneous databases -support
- Other databases? (PRs welcome)


## Installation

### Run directly with Elixir

This requires a local [Elixir](http://elixir-lang.org/) installation.

```
FOGHORN_DB="postgres://user:password@192.168.99.100:5432/database" mix run --no-halt
```

### Run with docker

No local [Elixir](http://elixir-lang.org/) installation required, but you will need [Docker](https://www.docker.com/products/overview).

```
docker run -ti -e "FOGHORN_DB=postgres://user:password@192.168.99.100:5432/database" -p 5555:5555 --rm luopio/foghorn:latest foreground
```

### Quick instructions on setting up Elixir (if needed)

```
brew install elixir
# git clone this repo and cd into it
mix deps.get
# have a psql db running and configure access in foghorn.ex
mix run --no-halt  # or "iex -S mix" for the repl experience
# open browser and go to localhost:5555, add a table to listen to
# change that table in the database and magic happens
```

## Compiling the Javascript code

The JS code is ES6 standard, thus it needs to be compiled to work on older browsers.
A precompiled file is available under [/priv/assets](./priv/assets/). Compilation requires Babel:

```
npm install
./compile_javascript.sh
```


## How to build the Docker container

On Mac OS X you'll need a separate image for building linux-compatible Elixir releases. On linux you can just run `compile_release.sh`.

Use the build-image to build an image that you can use for one-off compilations (cross-compile). Only needed on Mac. Only needed once.
```
docker build -t elixir-builder -f Dockerfile.build .
```

Build the release within the docker container
```
docker run -ti --rm -v $(pwd):/build elixir-builder /build/compile_release.sh
```

Build the final container that contains your new release which you can then run independently
```
docker build -t my_fancy_foghorn .
```




License: MIT
