# Foghorn

Watches your database for changes and notifies listening clients through websockets.

I.e. you do this in your client javascript:
```html
<script src="/assets/Foghorn.js" type="text/javascript"></script>
<script type="text/javascript">
  // Listen for changes on database table users, call console.log on changes
  Foghorn.listen(
    'users',
    function(tablename, type, id) {
      console.log('notified on', tablename, 'of a', type, 'for the id', id);
    });
```

And when the table changes the Foghorn server will tell your javascript what happened to which ID. Go update your view,
re-render your React, play the gong or what ever it is that you do when data changes.

## State

MVP/alpha(very)

## Supported databases

Only Postgres for now (via NOTIFY).

## Things to do

- Docker deployment
- CORS support
- Proper supervision tree
- Limit tables that notifications can be placed on
- Multiple simultaneous databases -support
- Publish to Hex
- Other databases? (PRs welcome)


## Installation

Very alpha stuff:

```
brew install elixir
# git clone this repo and cd into it
mix deps.get
# have a psql db running and configure access in foghorn.ex
mix run --no-halt  # or "iex -S mix" for the repl experience
# open browser and go to localhost:5555, add a table to listen to
# change that table in the database and magic happens
```



License: MIT