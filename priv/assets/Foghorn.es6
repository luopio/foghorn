
var Foghorn = (function() {
  var ret = {};
  var websocket = null;
  var connectionOpen = false;
  var listeners = [];

  var log = function() {
    log.history= log.history || []
    log.history.push(arguments)
    if(window.console && window.console.log.apply) {
      window.console.log.apply(window.console, arguments)
    }
  };

  ret.ADDRESS = 'ws://localhost:5555/ws';

  ret.listen = function(tablename, cb, connectedCallback) {
    ensureConnected(function () {
      log('FOGHORN: new callback for', tablename);
      var reqId = new Date().getTime();
      listeners.push({table: tablename, callback: cb, request_id: reqId, connected_callback: connectedCallback});
      websocket.send(JSON.stringify({op: 'LISTEN', table: tablename, request_id: reqId}));
    })
  };

  ret.unlisten = function(listenerId) {
    ensureConnected(function() {
      log('FOGHORN: remove callback with ID', listenerId);
      websocket.send(JSON.stringify({op: 'UNLISTEN', client_id: listenerId}));
      listeners = listeners.filter(function(listener) {
        return listener.client_id != listenerId;
      });
    });
  };

  ret.stop = function() {
    ensureConnected(function() {
      log('FOGHORN: remove ALL callbacks');
      websocket.send(JSON.stringify({op: 'STOP'}));
      listeners = [];
    })
  };

  function ensureConnected(func) {
    connect();
    if(connected()) {
      func();
    } else {
      log('FOGHORN: wait for connection to open...');
      setTimeout(function() { func(); }, 500);
    }
  }

  function notify(payload) {
    log('notify called with', payload);
    if(payload.op == 'LISTEN') {
      const newListeners = listeners.map((listener) => {
        if(listener.request_id == payload.request_id) {
          listener.connected_callback && listener.connected_callback.call(this, payload.client_id);
          return Object.assign(listener, {client_id: payload.client_id});
        }
        return listener;
      });
      listeners = newListeners;
    } else {
      listeners.forEach(function(listener) {
        if(listener.table == payload.table) {
          listener.callback.call(this, (payload.table || payload.client_id), payload.op, payload.id);
        }
      });
    }
  }

  function connected() {
    return connectionOpen;
  }

  function connect() {
    if(!websocket) {
      websocket = new WebSocket(ret.ADDRESS);
      websocket.onopen = function(evt) {
        // log('FOGHORN: on open', evt)
        connectionOpen = true;
      };
      websocket.onclose = function(evt) {
        // log('FOGHORN: on close', evt)
      };
      websocket.onmessage = function(evt) {
        // log('FOGHORN: on message', evt, this)
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



if(module) {
  module.exports = Foghorn;
}