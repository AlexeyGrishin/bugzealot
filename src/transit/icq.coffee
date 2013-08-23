oscar = require('oscar')

html2text = (html) ->
  html.replace(/<(?:.|)*?>/gm, '').replace(/\r/gm, '')

module.exports = (icqConfig) ->
  install: (transit) ->
    transit.server @

  _onError: (sender) ->
    (err) ->
      @icq.notifyTyping sender, oscar.TYPING_NOTIFY.TEXT_ENTERED
      @icq.sendIM(sender, "error: #{err}") if err

  start: (options) ->
    @icq = new oscar.OscarConnection({
      connection: {
        username: icqConfig.login,
        password: icqConfig.password,
        host: oscar.SERVER_ICQ
      }
    });

    @icq.on 'im', (text, sender, flags, ts) =>
      @icq.notifyTyping sender.name, oscar.TYPING_NOTIFY.START
      @callback user:sender.name, data:html2text(text), @_onError(sender).bind(@)
    @icq.on 'contactoffline', (sender) =>
      @callback user:sender.name, command:"exit", @_onError(sender).bind(@)

    @icq.connect (error) =>
      #TODO: make transit engine know about error
      if (error)
        console.error "Cannot connect to ICQ server"
        console.error error
      else
        @icq.getOfflineMsgs()

  receive: (@callback) ->
  sendBack: (userId, data, cb) ->
    html = """
           <html><body style='font-family: monospace'>#{data}</body></html>
           """
    @icq.sendIM userId, html, cb
    cb()