fs = require 'fs-extra'
WavWriter = (sampleRate) ->
  chunks = []
  write: (chunk) ->
    #console.log chunk
    chunks.push d for d in chunk
  reset: ->
    chunks = []
  finalize: (fileName) ->
    encoder = require 'wav-encoder'
    floats = new Float32Array chunks
    wav = await encoder.encode
      sampleRate: sampleRate
      channelData: [floats]
    await fs.writeFile fileName, Buffer.from(wav)
    
module.exports = WavWriter