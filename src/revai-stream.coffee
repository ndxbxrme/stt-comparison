revaiStream = (sampleRate) ->
  revai = require 'revai-node-sdk'
  token = process.env.REVAI_TOKEN
  callbacks = {}
  emit = (name, data) ->
    for fn in callbacks[name]
      fn data
  config = new revai.AudioConfig "audio/x-raw", "interleaved", sampleRate, "S16LE", 1
  client = null
  stream = null
  startStream = ->
    client = new revai.RevAiStreamingClient token, config
    client.on 'close', (code, reason) -> console.log "client closed #{code}, #{reason}"
    client.on 'httpResponse', (code) -> console.log "http response #{code}"
    client.on 'connectFailed', (error) -> console.log "connection failed, #{error}"
    client.on 'connect', (msg) -> console.log "connected, #{msg}"
    
    stream = client.start()
    stream.on 'data', speechCallback
    stream.on 'end', -> console.log "stream ended"
  speechCallback = (data) ->
    console.log 'data', data
    emit 'transcript', data
  write = (chunk) ->
    if stream
      stream.write chunk
  end = ->
    stream.removeListener 'data', speechCallback
    stream.end()
    stream = null

  console.log 'token', token

  startStream: startStream
  on: (name, fn) ->
    callbacks[name] = callbacks[name] or []
    callbacks[name].push fn
  write: write
  end: end

module.exports = revaiStream