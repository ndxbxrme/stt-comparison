
{ipcRenderer} = require 'electron'
AWSStream = require 'amazon-transcribe-websocket-static/lib/main.js'

viz = null
audio = null
source = null
gain = null
micGain = null
file = document.querySelector 'input[type=file]'
timer = new Date()
resetTimer = (full) ->
  timer = new Date()
getTime = ->
  ((new Date().getTime() - timer.getTime()) / 1000).toFixed(2)
ipcRenderer.on 'google-transcript', (win, results) ->
  time = getTime()
  transcript = results[0].alternatives[0].transcript
  lastPartial = document.querySelector '.google .partial'
  lastPartial.parentNode.remove(lastPartial) if lastPartial
  if transcript
    finalClass = if results[0].isFinal then 'final' else 'partial'
    transcriptElm.innerHTML += '<tr class="trans ' + finalClass + '"><td class="time">' + (time) + '</td><td class="text">' + transcript + '<td></tr>'
    document.querySelector('.google .transcript tbody:last-of-type')?.scrollIntoViewIfNeeded()
ipcRenderer.on 'revai-transcript', (win, data) ->
  time = getTime()
  transcript = ''
  transcript = data.elements.map (element) ->
    element.value
  .join ' '
  lastPartial = document.querySelector '.revai .partial'
  lastPartial.parentNode.remove(lastPartial) if lastPartial
  if transcript
    finalClass = if data.type is 'final' then 'final' else 'partial'
    revaiTranscriptElm.innerHTML += '<tr class="trans ' + finalClass + '"><td class="time">' + (time) + '</td><td class="text">' + transcript + '</td></tr>'
    document.querySelector('.revai .transcript tbody:last-of-type')?.scrollIntoViewIfNeeded()
awsTranscriptEvent = (results) ->
  time = getTime()
  transcript = results[0]?.Alternatives[0]?.Transcript
  lastPartial = document.querySelector '.aws .partial'
  lastPartial.parentNode.remove(lastPartial) if lastPartial
  if transcript
    finalClass = if results[0]?.IsPartial then 'partial' else 'final'
    awsTranscriptElm.innerHTML += '<tr class="trans ' + finalClass + '"><td class="time">' + (time) + '</td><td class="text">' + transcript + '<td></tr>'
    document.querySelector('.aws .transcript tbody:last-of-type')?.scrollIntoViewIfNeeded()
ipcRenderer.on 'deepspeech-transcript', (win, data) ->
  time = getTime()
  deepSpeechTranscriptElm.innerHTML += '<tr class="trans"><td class="time">' + time + '</td><td class="text">' + data.text + '</td><td></td></tr>'
  document.querySelector('.deepspeech .transcript tbody:last-of-type')?.scrollIntoViewIfNeeded()
ipcRenderer.on 'aws-transcript', (win, data) ->
  console.log 'aws', data
el = document.querySelector 'audio'
el.addEventListener 'play', ->
  resetTimer()
el.addEventListener 'pause', ->
  ipcRenderer.send 'finalize'
sampleRateElm = document.querySelector '.sample-rate'
transcriptElm = document.querySelector '.google .transcript'
revaiTranscriptElm = document.querySelector '.revai .transcript'
deepSpeechTranscriptElm = document.querySelector '.deepspeech-transcript'
awsTranscriptElm = document.querySelector '.aws .transcript'
channelSelect = document.querySelector '#channel'
showAllResults = document.querySelector '#all-results'
encoder = require 'wav-encoder'
setupAudio = ->
  audio.close() if audio
  audio = new AudioContext
    sampleRate: +sampleRateElm.value
  awsStream = AWSStream 8000
  awsStream.startStream()
  awsStream.on 'transcript', awsTranscriptEvent
  ipcRenderer.send 'start-stream',
    encoding: 'LINEAR16'
    sampleRate: audio.sampleRate
    languageCode: 'en-GB'
  micstream = await navigator.mediaDevices.getUserMedia
    audio: true
  mic = audio.createMediaStreamSource micstream
  if source
    source.disconnect gain
  source = audio.createMediaElementSource el
  dest = audio.createMediaStreamDestination()
  csp = audio.createScriptProcessor null, 2, 1
  gain = audio.createGain()
  micGain = audio.createGain()
  console.log audio.sampleRate

  csp.onaudioprocess = (e) ->
    inputBuffer = e.inputBuffer
    inputData = inputBuffer.getChannelData +channelSelect.value
    floats = []
    inputData.forEach (fl) ->
      floats.push fl
    ###
    wav = await encoder.encode
      sampleRate: audio.sampleRate
      channelData: [inputData]
    arr = new Int16Array(wav, 44)
    ###
    #console.log arr
    awsStream.write inputData
    ipcRenderer.send 'write-stream', 
      channelData: floats
      streamToGoogle: true
      streamToRevAI: true
      streamToDeepSpeech: false
      streamToWav: false
      streamToAws: true
    #console.log e
  source.connect gain
  mic.connect micGain
  gain.connect csp
  micGain.connect csp
  csp.connect dest
  analyser = audio.createAnalyser()
  analyser.fftSize = 2048
  viz = require('./viz') analyser
  gain.connect analyser
  micGain.connect analyser
  source.connect audio.destination
ipcRenderer.on 'sample-rate', (win, sr) ->
  sampleRateElm.value = sr
  setupAudio()
ipcRenderer.send 'get-sample-rate'
setSampleRate = ->
  ipcRenderer.send 'set-sample-rate', sampleRateElm.value
#console.clear()
draw = ->
  requestAnimationFrame draw
  viz.draw() if viz
draw()



  
module.exports =
  fileChange: ->
    console.log file.files[0].path
    el.src = file.files[0].path
    el.play()
  clearTranscript: ->
    transcriptElm.innerHTML = ''
    revaiTranscriptElm.innerHTML = ''
    deepSpeechTranscriptElm.innerHTML = ''
  toggleStream: (provider) ->
  setupAudio: setupAudio
  setSampleRate: setSampleRate
  resetTimer: resetTimer
  setWavGain: ->
    gain.gain.setValueAtTime +document.querySelector('.wav-gain input').value, audio.currentTime
  setMicGain: ->
    micGain.gain.setValueAtTime +document.querySelector('.mic-gain input').value, audio.currentTime