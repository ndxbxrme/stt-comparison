'use strict'

{app, BrowserWindow, ipcMain} = require 'electron'
{autoUpdater} = require 'electron-updater'
url = require 'url'
path = require 'path'
infiniteStreaming = require './infinite-streaming'
stream = null

mainWindow = null
ready = ->
  autoUpdater.checkForUpdatesAndNotify()
  mainWindow = new BrowserWindow
    width: 800
    height: 600
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
    mainWindow.webContents.send 'transcript', transcript
  ipcMain.on 'start-stream', (win, opts) ->
    stream = infiniteStreaming opts.encoding, opts.sampleRate, opts.languageCode, 290000
    stream.startStream()
    stream.on 'transcript', transcriptCallback
  ipcMain.on 'write-stream', (win, channelData) ->
    stream.write channelData if stream
app.on 'ready', ready
app.on 'window-all-closed', ->
  process.platform is 'darwin' or app.quit()
app.on 'activiate', ->
  mainWindow or ready()
  
transcribe = (path, channel) ->
  try
    speech = require '@google-cloud/speech'
    fs = require 'fs-extra'
    WavDecoder = require 'wav-decoder'
    WavEncoder = require 'wav-encoder'
    client = new speech.SpeechClient()
    file = await fs.readFile 'test.wav'
    wavData = await WavDecoder.decode file
    newData =
      sampleRate: wavData.sampleRate
      channelData: [wavData.channelData[channel]]
    buffer = await WavEncoder.encode newData
    await fs.writeFile 'result.wav', Buffer.from(buffer)
    audioBytes = Buffer.from(buffer).toString 'base64'
    audio =
      content: audioBytes
    config =
      encoding: 'LINEAR16'
      sampleRateHertz: 8000
      languageCode: 'en-US'
    request =
      audio: audio
      config: config

    response = await client.recognize request
    console.log response[0]
    transcription = response[0].results.map (result) ->
      result.alternatives[0].transcript
    .join '\n'
    transcription
#main()