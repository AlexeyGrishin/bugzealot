{EventEmitter} = require('events')

class UserSession extends EventEmitter
  constructor: (@userId) ->

  close: ->
    @emit "closed", @


class Sessions
  constructor: (@options = {}) ->
    @_sessions = {}
    @_idle = {}
    @_sessionClass = @options.sessionClass ? UserSession

  session: (id) ->
    session = @_sessions[id]
    if not session
      session = new @_sessionClass(id)
      @_sessions[id] = session
      if @options.forgetOnIdle
        @_idle[id] = interval: @options.forgetOnIdle, to: null
    if @_idle[id]?.interval
      clearTimeout @_idle[id]?.to
      @_idle[id].to = setTimeout (=>forget(id)), @_idle[id].interval
    session

  forget: (id) ->
    @_sessions[id]?.close()
    delete @_sessions[id]

  install: (transit) ->
    transit.use (req, res, next) =>
      userId = req.user
      if req.command == 'exit'
        @forget userId
      else
        req.session = @session userId
        if req.session?.postCreate
          return req.session.postCreate -> next(req, res)
      next(req, res)
    undefined

module.exports = Sessions
