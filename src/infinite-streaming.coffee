infiniteStream = (encoding, sampleRateHertz, languageCode, streamingLimit) ->
  {Transform} = require 'stream'
  speech = require('@google-cloud/speech').v1p1beta1
  client = new speech.SpeechClient()
  config =
    encoding: encoding
    sampleRateHertz: sampleRateHertz
    languageCode: languageCode
    single_utterance: true
  request =
    config: config
    interimResults: true
  recognizeStream = null
  restartCounter = 0
  audioInput = []
  lastAudioInput = []
  resultEndTime = 0
  isFinalEndTime = 0
  finalRequestEndTime = 0
  newStream = true
  bridgingOffset = 0
  lastTranscriptwasFinal = false
  callbacks = {}
  emit = (name, data) ->
    for fn in callbacks[name]
      fn data
  
  startStream = ->
    console.log 'stream starting'
    audioInput = []
    recognizeStream = client
    .streamingRecognize request
    .on 'error', (err) ->
      if err.code is 11
        #restartStream()
      else
        console.error 'API request error', err
    .on 'data', speechCallback
    
  speechCallback = (stream) ->
    resultEndTime = +stream.results[0].resultEndTime.seconds * 1000 + Math.round(stream.results[0].resultEndTime.nanos / 1000000)
    correctedTime = resultEndTime - bridgingOffset + streamingLimit * restartCounter
    stdoutText = ''
    if stream.results?[0].alternatives?[0]
      stream.results[0].correctedTime = correctedTime
      stdoutText = correctedTime + ': ' + stream.results[0].alternatives[0].transcript + ' : ' + stream.results[0].isFinal
      emit 'transcript', stream.results
      isFinalEndTime = resultEndTime
      lastTranscriptwasFinal = true
    else
      lastTranscriptwasFinal = false
      
  write = (chunk) ->
    if newStream and lastAudioInput.length isnt 0
      chunkTime = streamingLimit / lastAudioInput.length
      if chunkTime isnt 0
        if bridgingOffset < 0
          bridgingOffset = 0
        if bridgingOffset > finalRequestEndTime
          bridingOffset = finalRequestEndTime
        chunksFromMS = Math.floor (finalRequestEndTime - bridgingOffset) / chunkTime
        bridgingOffset = Math.floor (lastAudioInput.length - chunksFromMS) * chunkTime
        i = chunksFromMS
        while i<lastAudioInput.length
          recognizeStream.write lastAudioInput[i]
          i++
      newStream = false
    audioInput.push chunk
    if recognizeStream
      recognizeStream.write chunk
      
  restartStream = ->
    if recognizeStream
      recognizeStream.removeListener 'data', speechCallback
      recognizeStream = null
    if resultEndTime > 0
      finalRequestEndTime = isFinalEndTime
    resultEndTime = 0
    lastAudioInput = []
    lastAudioInput = audioInput
    restartCounter++
    console.log 'restarting request'
    newStream = true
    startStream()
  startStream: startStream
  on: (name, fn) ->
    callbacks[name] = callbacks[name] or []
    callbacks[name].push fn
  write: write
  end: ->
    if recognizeStream
      recognizeStream.removeListener 'data', speechCallback
      recognizeStream = null
    recognizeStream = null
    restartCounter = 0
    audioInput = []
    lastAudioInput = []
    resultEndTime = 0
    isFinalEndTime = 0
    finalRequestEndTime = 0
    newStream = true
    bridgingOffset = 0
    lastTranscriptwasFinal = false
module.exports = infiniteStream