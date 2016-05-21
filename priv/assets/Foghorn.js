window.log=function(){log.history=log.history||[];log.history.push(arguments);if(this.console&&console.log.apply){console.log.apply(console, arguments)}};

var Foghorn = (function() {
  var ret = {};
  var websocket = null;
  var connectionOpen = false;
  var tableCallbacks = {};

  ret.listen = function(tablename, cb) {
    connect();
    if(connected()) {
      if(!tableCallbacks[tablename]) {
        tableCallbacks[tablename] = [];
      }
      log('new callback for', tablename)
      tableCallbacks[tablename].push(cb);
      websocket.send(tablename);
    } else {
      log('wait for connection to open...');
      setTimeout(function() { ret.listen(tablename, cb); }, 500);
    }
  };

  function notify(payload) {
    log('notify called with', payload)
    if(tableCallbacks[payload.table]) {
      for(var i = 0; i < tableCallbacks[payload.table].length; i++) {
        tableCallbacks[payload.table][i].call(this, payload.table, payload.op, payload.id);
      }
    }
  }

  function connected() {
    return connectionOpen;
  }

  function connect() {
    if(!websocket) {
      websocket = new WebSocket('ws://localhost:5555/ws');
      websocket.onopen = function(evt) {
        // log('on open', evt)
        connectionOpen = true;
      };
      websocket.onclose = function(evt) {
        // log('on close', evt)
      };
      websocket.onmessage = function(evt) {
        // log('on message', evt, callback, this)
        var payload = JSON.parse(evt.data);
        notify(payload);
      };
    }
    return websocket;
  }

  function disconnect() {
    websocket.close();
    connectionOpen = false;
  }

  return ret;
}());