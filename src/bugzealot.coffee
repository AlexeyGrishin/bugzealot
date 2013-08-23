transit = require('./transit/transit')
withEjs = require('./transit/renderers/ejs')(disableCache: true)
withColumns = require('./transit/renderers/columnizer')()
Sessions = require('./session')
BugzillaClient = require('./bugzilla/bugzilla')
UsersStorage = require('./userstorage')
aimServer = require('./transit/icq')
fs = require('fs')
config = null
loadConfig = () ->
  config = JSON.parse(fs.readFileSync('./config.json', 'utf-8'))
setInterval loadConfig, 5000
loadConfig()

#TODO: move out with the session
storage = new UsersStorage url:"http://localhost", port:5984, database:"bugzealot"

class BugzillaSession
  constructor: (@userId) ->
    storage.register @userId
    @bugzilla = new BugzillaClient("http://#{config.bugzilla.server}:#{config.bugzilla.port}")
    #@bugzilla = new BugzillaClient("http://bugzilla.actimind.com:1111")

  postCreate: (cb) ->
    storage.load @userId, (err, @data) =>
      if @data?.username
        @bugzilla.login @data.username, @data.password, cb
      else
        cb()

  onLogin: (username, password) ->
    storage.put @userId, {username, password}

  close: ->
    @bugzilla.close()


transit.use(transit.parseRequest)
transit.use(transit.findPattern)
#transit.use(transit.commandLine)
transit.use(aimServer(config.icq))
transit.use(new Sessions(sessionClass: BugzillaSession))
transit.use(transit.renderWith(
  ((error) -> error.toString()),
  ((data) -> JSON.stringify(data, null, 4)))
)


transit.on 'login {username} {password}', (req, res) ->
  req.session.bugzilla.login req.username, req.password, (err) ->
    req.session.onLogin req.username, req.password
    res.sendBack if err then err else "OK"


transit.on 'get {bug}', (req, res) ->
  req.session.bugzilla.getBug req.bug, res.render withEjs("bug")

transit.on 'list {{options}}', (req, res) ->
  req.session.bugzilla.listBugs req.options, res.render withColumns {
    id: null,
    priority: ((p, item) -> "#{p}/#{item.severity}"),
    product: null,
    summary: null,
    status: ((_) -> "[#{_}]"),
    assigned_to: (_) -> " -> #{_}"

  }

transit.on 'fields', (req, res) ->
  req.session.bugzilla.getFields res.render withEjs("fields")

transit.on 'take {bug}', (req, res) ->
  req.session.bugzilla.takeBug req.bug, res.render -> "OK"

transit.on 'done {bug}', (req, res) ->
  req.session.bugzilla.completeBug req.bug, res.render -> "OK"

transit.start()