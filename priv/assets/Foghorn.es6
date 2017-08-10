const Foghorn = (function() {
  const _version = "2"
  let ret = {};
  let websocket = null;
  let connectionOpen = false;
  let listeners = [];

  const log = function() {
    log.history= log.history || []
    log.history.push(arguments)
    if(window.console && window.console.log.apply) {
      window.console.log.apply(window.console, arguments)
    }
  };

  ret.ADDRESS = 'ws://localhost:5555/ws';

  ret.listen = function(directives, cb, connectedCallback) {
    ensureConnected(function () {
      log('FOGHORN: new callback for directive', directives);
      let reqId = new Date().getTime();
      if(typeof directives === "string") {
        directives = [directives]
      }
      directives.forEach((directive) => {
        listeners.push({directive: directive, callback: cb, request_id: reqId, connected_callback: connectedCallback});
        websocket.send(JSON.stringify({op: 'LISTEN', directive: directive, request_id: reqId}));
      })
    })
  };

  ret.unlisten = function(listenerId) {
    ensureConnected(function() {
      log('FOGHORN: remove callback with ID', listenerId);
      websocket.send(JSON.stringify({op: 'UNLISTEN', client_id: listenerId}));
      listeners = listeners.filter(function(listener) {
        return listener.client_id !== listenerId;
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

  ret.connected = function() {
    return connected()
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
    // log('notify called with', payload);
    if(payload.op === 'LISTEN') {
      const newListeners = listeners.map((listener) => {
        if(listener.request_id === payload.request_id) {
          listener.connected_callback && listener.connected_callback.call(this, payload.client_id);
          return Object.assign(listener, {client_id: payload.client_id});
        }
        return listener;
      });
      listeners = newListeners;
    } else {
      listeners.forEach(function(listener) {
        if(listener.directive == payload.directive) {
          listener.callback.call(this, (payload.directive || payload.client_id), payload.op, payload.payload);
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