'use strict'

{app, BrowserWindow, ipcMain} = require 'electron'
{autoUpdater} = require 'electron-updater'
url = require 'url'
path = require 'path'
infiniteStreaming = require './infinite-streaming'
RevAiStream = require './revai-stream'
deepSpeech = require './deepspeech'
stream = null
revaiStream = null
deepSpeechStream = null

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
    console.log 'transcript', transcript
    mainWindow.webContents.send 'google-transcript', transcript
  revaiTranscriptCallback = (data) ->
    mainWindow.webContents.send 'revai-transcript', data
  deepSpeechTranscriptCallback = (data) ->
    mainWindow.webContents.send 'deepspeech-transcript', data
  ipcMain.on 'start-stream', (win, opts) ->
    #stream = infiniteStreaming opts.encoding, opts.sampleRate, opts.languageCode, 290000
    #stream.startStream()
    #stream.on 'transcript', transcriptCallback
    revaiStream = RevAiStream opts.sampleRate
    revaiStream.startStream()
    revaiStream.on 'transcript', revaiTranscriptCallback
    #deepSpeechStream = deepSpeech opts.sampleRate
    #deepSpeechStream.startStream()
    #deepSpeechStream.on 'transcript', deepSpeechTranscriptCallback
  ipcMain.on 'write-stream', (win, channelData) ->
    #stream.write channelData if stream
    revaiStream.write channelData if revaiStream
    #deepSpeechStream.write channelData if deepSpeechStream
  ipcMain.on 'end-stream', (win) ->
    #stream.end()
    #revaiStream.end()
app.on 'ready', ready
app.on 'window-all-closed', ->
  process.platform is 'darwin' or app.quit()
app.on 'activiate', ->
  mainWindow or ready()
