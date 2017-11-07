const Foghorn = (function() {
  const _version = "2.3.0"
  const pingInterval = 30000
  let ret = {}
  let websocket = null
  let currentClientId = null
  let listeners = []
  let lastConnection = -1
  let failedConnections = 0
  let pingIntervalId = null

  const log = function() {
    log.history = log.history || []
    log.history.push(arguments)
    if(window.console && window.console.log.apply) {
      window.console.log.apply(window.console, arguments)
    }
  }

  ret.ADDRESS = 'ws://localhost:5555/ws'

  ret.listen = function(directives, cb) {
    log('FOGHORN.listen: called for', directives)
    ensureConnected(function() {
      log('FOGHORN: new callback for directive', directives)
      let reqId = new Date().getTime()
      if(typeof directives === "string") {
        directives = [directives]
      }
      directives.forEach((directive) => {
        listeners.push({directive: directive, callback: cb, request_id: reqId})
      })
      websocket.send(JSON.stringify({op: 'LISTEN', directives: directives, request_id: reqId, client_id: currentClientId}))
    })
  }

  ret.unlisten = function() {
    ensureConnected(function() {
      log('FOGHORN.unlisten')
      websocket.send(JSON.stringify({op: 'UNLISTEN', client_id: currentClientId}))
    })
  }

  ret.connected = function() {
    return connected()
  }

  function ensureConnected(func) {
    connect()
    if(connected()) {
      func()
    } else {
      log('FOGHORN: wait for connection to open...')
      if(failedConnections < 10) {
        setTimeout(function() {
          ensureConnected(func)
        }, 1500)
      }
    }
  }

  function notify(payload) {
    log('FOGHORN: notify called with', payload, 'listeners:', listeners)
    // Return message from a LISTEN request
    if(payload.op === 'LISTEN') {
      const newListeners = listeners.map((listener) => {
        if(listener.request_id === payload.request_id) {
          return Object.assign(listener, {client_id: payload.client_id})
        }
        return listener
      })
      currentClientId = payload.client_id
      listeners = newListeners
    }
    else if(payload.op === 'RECONNECT') {
      log('FOGHORN: reconnect successful for', payload.client_id)
    }
    else if(payload.op === 'UNLISTEN') {
      log('FOGHORN: unlisten successful for', payload.client_id)
      listeners = []
    }
    // Actual notifications being sent to listeners
    else {
      listeners.forEach(function(listener) {
        if(listener.directive === payload.directive) {
          listener.callback.call(this, payload.directive, payload.op, payload.payload)
        }
      })
    }
  }

  function connected() {
    return websocket.readyState === WebSocket.OPEN
  }

  function disconnect() {
    if(connected()) {
      websocket.close()
      clearInterval(pingIntervalId)
      pingIntervalId = null
    }
  }

  function ping() {
    const ct = new Date().getTime()
    const dt = ct - lastConnection
    if(dt > pingInterval) {
      if(connected()) {
        websocket.send('PING')
      }
      if(dt > pingInterval * 2) {
        // reconnect...
        disconnect()
        connect()
      }
    }
  }

  function connect() {

    if(websocket) {
      if(websocket.readyState === WebSocket.CONNECTING || websocket.readyState === WebSocket.OPEN) {
        return true
      }
      disconnect()
    }

    if(failedConnections < 10) {
      websocket = new WebSocket(ret.ADDRESS)
    } else {
      if(failedConnections === 10) {
        log('FOGHORN: more than 10 failed connection attempts, giving up')
      }
      return false
    }

    websocket.onopen = function(evt) {
      log('FOGHORN: +++ on open', evt)
      lastConnection = new Date().getTime()
      failedConnections = 0
      // Is this a reconnect of a previous listening session? If so, then reconnect to get the same notifications
      if(currentClientId) {
        websocket.send(JSON.stringify({op: 'RECONNECT', client_id: currentClientId}))
      }
    }

    websocket.onclose = function(evt) {
      log('FOGHORN: --- on close', evt.code, evt)
      // reconnect...
      disconnect()
      connect()
    }
    websocket.onmessage = function(evt) {
      log('FOGHORN websocket.onmessage:', evt, this)
      lastConnection = new Date().getTime()
      if(evt.data !== 'PONG') {
        const payload = JSON.parse(evt.data)
        notify(payload)
      }
    }
    websocket.onerror = function(evt) {
      failedConnections += 1
      log('FOGHORN websocket.onerror: failed connections', failedConnections, evt)
    }

    if(!pingIntervalId) {
      log('FOGHORN: set up pinging')
      pingIntervalId = setInterval(ping, pingInterval)
    }
    return websocket
  }

  ret._close = () => {
    disconnect()
    connect()
  }

  return ret

}())


if(module) {
  module.exports = Foghorn
}
