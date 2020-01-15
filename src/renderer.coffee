
{ipcRenderer} = require 'electron'
{Transform} = require 'stream'

file = document.querySelector 'input[type=file]'
allResults = []
ipcRenderer.on 'google-transcript', (win, results) ->
  lastResult = allResults[allResults.length - 1]
  transcript = ''
  if lastResult and not lastResult.isFinal and not results[0].isFinal and not showAllResults.checked
    transcript = results[0].alternatives[0].transcript.replace(lastResult.alternatives[0].transcript, '')
  else
    transcript = results[0].alternatives[0].transcript
  allResults.push results[0]
  if transcript
    transcriptElm.innerHTML += '<tr class="trans"><td>' + results[0].correctedTime + '</td><td class="text">' + transcript + '<td><td>' + results[0].isFinal + '</td></tr>'
ipcRenderer.on 'revai-transcript', (win, data) ->
  console.log 'revai transcript'
  transcript = ''
  transcript = data.elements.map (element) ->
    element.value
  .join ' '
  if (transcript.trim() and data.type is 'final') or showAllResults.checked
    revaiTranscriptElm.innerHTML += '<tr class="trans"><td>' + data.end_ts + '</td><td class="text">' + transcript + '</td><td>' + (data.type is 'final') + '</td></tr>'
ipcRenderer.on 'deepspeech-transcript', (win, data) ->
  deepSpeechTranscriptElm.innerHTML += '<tr class="trans"><td></td><td class="text">' + data.text + '</td><td></td></tr>'
el = document.querySelector 'audio'
###
el.addEventListener 'play', ->
  ipcRenderer.send 'start-stream',
    encoding: 'LINEAR16'
    sampleRate: audio.sampleRate
    languageCode: 'en-GB'
el.addEventListener 'pause', ->
  ipcRenderer.send 'end-stream'
###
transcriptElm = document.querySelector '.transcript'
revaiTranscriptElm = document.querySelector '.revai-transcript'
deepSpeechTranscriptElm = document.querySelector '.deepspeech-transcript'
channelSelect = document.querySelector '#channel'
showAllResults = document.querySelector '#all-results'
encoder = require 'wav-encoder'

audio = new AudioContext()
wavTools = require('./wavtools') audio.sampleRate, 16000
source = audio.createMediaElementSource el
dest = audio.createMediaStreamDestination()
csp = audio.createScriptProcessor 8192, 2, 1
gain = audio.createGain()
gain.gain.setValueAtTime 2.0, audio.currentTime
console.log audio.sampleRate

csp.onaudioprocess = (e) ->
  inputBuffer = e.inputBuffer
  inputData = inputBuffer.getChannelData +channelSelect.value
  wav = await encoder.encode
    sampleRate: audio.sampleRate
    channelData: [inputData]
  arr = new Int16Array(wav, 44)
  #console.log arr
  ipcRenderer.send 'write-stream', arr
  #console.log e
source.connect gain
gain.connect csp
csp.connect dest
analyser = audio.createAnalyser()
analyser.fftSize = 2048
viz = require('./viz') analyser
gain.connect analyser
gain.connect audio.destination
#console.clear()
draw = ->
  requestAnimationFrame draw
  viz.draw() if viz
draw()
ipcRenderer.send 'start-stream',
  encoding: 'LINEAR16'
  sampleRate: audio.sampleRate
  languageCode: 'en-GB'


  
module.exports =
  fileChange: ->
    console.log file.files[0].path
    el.src = file.files[0].path
    el.play()
  clearTranscript: ->
    transcriptElm.innerHTML = ''
    revaiTranscriptElm.innerHTML = ''
    deepSpeechTranscriptElm.innerHTML = ''