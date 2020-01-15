deepSpeech = (sampleRate) ->
  callbacks = {}
  emit = (name, data) ->
    for fn in callbacks[name]
      fn data
  DeepSpeech = require 'deepspeech'
  console.log 'required deepspeech'
  VAD = require 'node-vad'
  console.log 'required vad'
  DEEPSPEECH_MODEL=process.env.DEEPSPEECH_MODEL
  if not DEEPSPEECH_MODEL
    DEEPSPEECH_MODEL = 'C:/Dev/github/stt-comparison/deepspeech-0.6.0-models'
  SILENCE_THRESHOLD = 200
  VAD_MODE = VAD.Mode.VERY_AGGRESSIVE
  vad = new VAD VAD_MODE
  console.log 'made vad'
  createModel = (modelDir, options) ->
    console.log 'making model', modelDir, options
    modelPath = modelDir + '/output_graph.pbmm'
    lmPath = modelDir + '/lm.binary'
    triePath = modelDir + '/trie'
    model = new DeepSpeech.Model modelPath, options.BEAM_WIDTH
    model.enableDecoderWithLM lmPath, triePath, options.LM_ALPHA, options.LM_BETA
    model
  englishModel = createModel DEEPSPEECH_MODEL,
    BEAM_WIDTH: 1024
    LM_ALPHA: 0.75
    LM_BETA: 1.85
  console.log 'english model', englishModel
  modelStream = null
  recordedChunks = 0
  silenceStart = null
  recordedAudioLength = 0
  endTimeout = null
  silenceBuffers = []
  firstChunkVoice = false
  processAudioStream = (data, callback) ->
    vad.processAudio data, sampleRate
    .then (res) ->
      if firstChunkVoice
        firstChunkVoice = false
        processVoice data
        return
      switch res
        ###
        when VAD.Event.ERROR then console.log 'VAD_ERROR'
        when VAD.Event.NOISE then console.log 'VAD_NOISE'
        ###
        when VAD.Event.SILENCE then processSilence data, callback
        when VAD.Event.VOICE then processVoice data
        #else console.log 'default'
    clearTimeout endTimeout
    endTimeout = setTimeout ->
      console.log 'timeout'
      resetAudioStream()
    , SILENCE_THRESHOLD * 3
  endAudioStream = (callback) ->
    console.log 'end'
    results = intermediateDecode()
    if results
      if callback
        callback results
  resetAudioStream = ->
    clearTimeout endTimeout
    console.log 'reset'
    intermediateDecode()
    recordedChunks = 0
    silenceStart = null
  processSilence = (data, callback) ->
    console.log 'process silence'
    if recordedChunks > 0
      console.log '-'
      feedAudioContent data
      if silenceStart is null
        silenceStart = new Date().getTime()
      else
        now = new Date().getTime()
        if now - silenceStart > SILENCE_THRESHOLD
          silenceStart = null
          console.log '[end]'
          results = intermediateDecode()
          if results
            if callback
              callback results
    else
      console.log '.'
      bufferSilence data
  bufferSilence = (data) ->
    silenceBuffers.push data
    if silenceBuffers.length >= 3
      silenceBuffers.shift()
  addBufferedSilence = (data) ->
    audioBuffer = null
    if silenceBuffers.length
      silenceBuffers.push data
      length = 0
      silenceBuffers.forEach (buf) ->
        length += buf.length
      audioBuffer = Buffer.concat silenceBuffers, length
      silenceBuffers = []
    else
      audioBuffer = data
    audioBuffer
  processVoice = (data) ->
    console.log 'pv', data
    silenceStart = null
    recordedChunks++
    data = addBufferedSilence data
    feedAudioContent data
  createStream = ->
    console.log 'create stream'
    modelStream = englishModel.createStream()
    recordedChunks = 0
    recordedAudioLength = 0
  finishStream = ->
    console.log 'finish stream'
    if modelStream
      start = new Date()
      text = englishModel.finishStream modelStream
      if text
        if text is 'i' or text is 'a'
          return
        recogTime = new Date().getTime() - start.getTime()
        return
          text: text
          recogTime: recogTime
          audioLength: Math.round recordedAudioLength
    silenceBuffers = []
    modelStream = null
  intermediateDecode = ->
    results = finishStream()
    createStream()
    results
  feedAudioContent = (chunk) ->
    console.log 'feedAudioContent'
    recordedAudioLength += (chunk.length) * (1 / sampleRate) * 1000
    console.log 'model stream', modelStream
    englishModel.feedAudioContent modelStream, chunk
    console.log 'fed'
  speechCallback = (results) ->
    console.log 'speech callback'
    console.log results
    emit 'transcript', results
  write = (data) ->
    processAudioStream data, speechCallback
  
  startStream: createStream
  on: (name, fn) ->
    callbacks[name] = callbacks[name] or []
    callbacks[name].push fn
  write: write
  end: finishStream
module.exports = deepSpeech