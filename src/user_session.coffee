BugzillaClient = require("./bugzilla/bugzilla")

class BugzillaUserSession
  constructor: (@userId, @storage, config) ->
    @storage.register @userId
    @bugzilla = new BugzillaClient("http://#{config.server}:#{config.port}")

  postCreate: (cb) ->
    @storage.load @userId, (err, @data) =>
      if @data?.username
        @bugzilla.login @data.username, @data.password, cb
      else
        cb()

  onLogin: (username, password) ->
    @storage.put @userId, {username, password}

  close: ->
    @bugzilla.close()

module.exports = (storage, conf) ->
  class Configured extends BugzillaUserSession
    constructor: (@userId) ->
      super @userId, storage, conf
  Configured