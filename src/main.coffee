'use strict'

{app, BrowserWindow} = require 'electron'
{autoUpdater} = require 'electron-updater'
url = require 'url'
path = require 'path'

mainWindow = null
ready = ->
  autoUpdater.checkForUpdatesAndNotify()
  mainWindow = new BrowserWindow
    width: 800
    height: 600
  mainWindow.on 'closed', ->
    mainWindow = null
  mainWindow.loadURL url.format
    pathname: path.join __dirname, 'index.html'
    protocol: 'file:'
    slashes: true
app.on 'ready', ready
app.on 'window-all-closed', ->
  process.platform is 'darwin' or app.quit()
app.on 'activiate', ->
  mainWindow or ready()