'use strict'

{app, BrowserWindow, ipcMain} = require 'electron'
{autoUpdater} = require 'electron-updater'
url = require 'url'
path = require 'path'
infiniteStreaming = require './infinite-streaming'
RevAiStream = require './revai-stream'
#deepSpeech = require './deepspeech'
WavWriter = require './wavwriter'
wavTools = require './wavtools'
AwsStream = require 'amazon-transcribe-websocket-static/lib/main.js'
googleStream = null
revaiStream = null
deepSpeechStream = null
wavWriter = null
sampleRate = 16000

mainWindow = null
ready = ->
  autoUpdater.checkForUpdatesAndNotify()
  mainWindow = new BrowserWindow
    width: 1024
    height: 800
    webPreferences:
      nodeIntegration: true
  mainWindow.on 'closed', ->
    mainWindow = null
  mainWindow.loadURL url.format
    pathname: path.join __dirname, 'index.html'
    protocol: 'file:'
    slashes: true
  #mainWindow.openDevTools()
  transcriptCallback = (transcript) ->
    mainWindow.webContents.send 'google-transcript', transcript
  revaiTranscriptCallback = (data) ->
    mainWindow.webContents.send 'revai-transcript', data
  deepSpeechTranscriptCallback = (data) ->
    mainWindow.webContents.send 'deepspeech-transcript', data
  awsTranscriptCallback = (data) ->
    console.log 'AWS transcript', data
    mainWindow.webContents.send 'aws-transcript', data
  ipcMain.on 'start-stream', (win, opts) ->
    sampleRate = opts.sampleRate
    googleStream.end() if googleStream
    revaiStream.end() if revaiStream
    wavWriter.reset() if wavWriter
    googleStream = infiniteStreaming opts.encoding, opts.sampleRate, opts.languageCode, 290000
    googleStream.startStream()
    googleStream.on 'transcript', transcriptCallback
    revaiStream = RevAiStream opts.sampleRate
    revaiStream.startStream()
    revaiStream.on 'transcript', revaiTranscriptCallback
    ###
    deepSpeechStream = deepSpeech opts.sampleRate
    deepSpeechStream.startStream()
    deepSpeechStream.on 'transcript', deepSpeechTranscriptCallback
    ###
    #wavWriter = WavWriter opts.sampleRate
  ipcMain.on 'write-stream', (win, data) ->
    pcmData = wavTools.floatTo16BitPCM data.channelData
    #ds8k = wavTools.downsampleBuffer pcmData, sampleRate, 8000
    googleStream.write pcmData if googleStream and data.streamToGoogle
    revaiStream.write pcmData if revaiStream and data.streamToRevAI
    #deepSpeechStream.write pcmData if deepSpeechStream and data.streamToDeepSpeech
    #wavWriter.write data.channelData if data.streamToWav
  ipcMain.on 'finalize-wav', ->
    wavWriter.finalize 'ww.wav'
  ipcMain.on 'reset-wav', ->
    wavWriter.reset()
  ipcMain.on 'end-stream', (win) ->
    stream.end()
    revaiStream.end()
  ipcMain.on 'get-sample-rate', (win) ->
    mainWindow.webContents.send 'sample-rate', sampleRate
  ipcMain.on 'set-sample-rate', (win, sr) ->
    sampleRate = +sr
    mainWindow.reload()
app.on 'ready', ready
app.on 'window-all-closed', ->
  process.platform is 'darwin' or app.quit()
app.on 'activiate', ->
  mainWindow or ready()
