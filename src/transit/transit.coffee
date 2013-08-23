parse = require('./parser').parseCommand
parsePattern = require('./parser').parsePattern
commandLine = require('./cmdline')
#TODO: error processing
#TODO: documentation
###
  Server interface
  - start(options) - starts server
  - receive(callback) - the callback will be called when something is coming from client.
    callback will be called with the following parameters:
    - request - structure:
      - user - user id
      - data - data (see below)
      - command - command (see below)
    - callback(error)
  - sendBack(userId, data, cb)

  req object
  - user - id of the client user
  - data - data sent by client user. may be null
  - command - command sent by client user. usually is 'data'. other possible values:
    'exit'
  - session (if usin session middleware) - session object related to that user id

  res object
  - done - request is processed, nothing shall be sent back to client.
  - sendBack(data) - the data shall be sent back to the client in respose to request
  - data - data to be sent back. If present will be sent back automatically
  - error - error to be sent back

  Note: at least one of the res methods shall be called in user's handlers.
  Note 2: if middleware adds some method to res object this method shall call to 'next'
###
class Transit
  constructor: ->
    @_chainBefore = []
    @_server = null
    @_patterns = []
    @_errorCallbacks = [
      (err) ->
        console.error(err)
        console.error(err.stack)
    ]

  #TODO: make it support several servers
  server: (server) ->
    @_server = server
    undefined

  use: (middle) ->
    if typeof middle == 'object'
      middle = middle.install(@)
    @_chainBefore.push(middle) if middle
    undefined

  _onRequest: (request, callback) ->
    chain = @_chainBefore.slice()
    if request.data
      chain.push (req, res) =>
        req.userCallback req, res
    chain.push (req, res) ->
      if res.data
        res.sendBack res.data
      callback(res.error)

    callCtx =
      req:
        user: request.user
        data: request.data
        command: request.command
        patterns: @_patterns
      res:
        error: null
        data: null
        sendBack: (data) =>
          @send request.user, data, ->
          doNext()
        done: () ->
          doNext()
    doNext = (req, res) =>
      callCtx.req = req if req
      callCtx.res = res if res
      nextStep = chain.shift()
      return if not nextStep
      process.nextTick =>
        try
          nextStep(callCtx.req, callCtx.res, doNext)
        catch e
          for cb in @_errorCallbacks
            cb(e)
          callback e


    doNext()

  subscribe: (pattern, cb) ->
    @_patterns.push parsePattern(pattern, cb)

  start: (options) ->
    @_server.receive @_onRequest.bind(@)
    @_server.start options

  send: (userId, data, cb) ->
    @_server.sendBack userId, data, cb

middlewares =
  parseRequest: (req, res, next) ->
    req.parsed = parse(req.data) if req.data
    next(req, res)

  renderWith: (errorRenderer, defaultRenderer) ->
    (req, res, next) ->
      generateCallback = (composeResult) ->
        (err, data) ->
          if typeof err == 'function'
            return generateCallback(err)
          if err
            res.error = errorRenderer(err)
          else if data
            res.data = composeResult(data)
          next(req, res)
      res.render = generateCallback(defaultRenderer)
      next req, res

  commandLine: commandLine

  findPattern: (req, res, next) ->
    return next() if not req.parsed
    matched = (req.patterns.map (p) -> p.match(req.parsed.cmd, req.parsed.args)).filter (r) -> r
    if matched.length == 0
      throw "Cannot find handler for #{req.data}"
    req.userCallback = matched[0].cb
    for name, value of matched[0].args
      req[name] = value
    next()


transit = new Transit()
module.exports =
  register: (name, middleware) ->
    @[name] = middleware

  use: (middleware) ->
    transit.use(middleware)

  start: (options) ->
    transit.start(options)

  send: (userId, data, cb) ->
    transit.send(userId, data, cb)

  on: (command, cb) ->
    transit.subscribe(command, cb)

for name, method of middlewares
  module.exports.register name, method