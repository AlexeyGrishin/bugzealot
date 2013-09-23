_ = require('underscore')
transit = require('../node_modules/transit-im/src/transit')
config = require('../config.json')
storage = new (require('./userstorage'))(config.couchdb)
Session = require('./user_session')(storage, config.bugzilla)
ejs = require("./middleware/ejs")
columns = require("./middleware/columns")

app = transit()
#app.use transit.icq config.icq
app.use transit.commandLine()

app.use transit.alias storage.loadAliases.bind(storage), storage.saveAliases.bind(storage)

app.use transit.html2txt()
app.use transit.commandParser()
app.use transit.sessions sessionClass:Session

app.formatOutput "json",    transit.chain transit.chain.json()
app.formatOutput "ejs",     transit.chain ejs(disableCache: true), transit.chain.wrapHtml()
app.formatOutput "columns", transit.chain columns(50), transit.chain.splitByPortions(2000), transit.chain.wrapHtml()
app.formatOutput "ok",      (data, options, cb) -> cb(data ? "OK")
app.formatOutput transit.chain transit.chain.wrapHtml()

help =
  login:
    autohelp: "logins to the bugzilla. Your login and password will be saved and used next time for auto login.
      You may use this command to change user"
  get:
    autohelp: "gets full information about bug with specified id"
  list:
    autohelp: "prints a list of bugs where one of the fields matches provided options, for example: 'list Product1 CONFIRMED'"
  update:
    autohelp: "updates bug (or several bugs) with specified bug ids (comma separated)."
  updateList:
    autohelp: "combines list (to find bugs by some criteria) and update (to change them). Note that list options shall be in quotes in this case, like 'updateList \"Product2 CONFIRMED\" assigned_to=user@acme.com '"



app.receive 'login {username} {password}', (req, res) ->
  req.session.bugzilla.login req.attrs.username, req.attrs.password, (err) ->
    req.session.onLogin req.username, req.password
    res.ok err


app.receive 'get {bug}', (req, res) ->
  req.session.bugzilla.getBug req.attrs.bug, (err, data) ->
    return res.sendBack err if err
    res.ejs data, "bug"

app.receive 'list {{options}}', (req, res) ->
  req.session.bugzilla.listBugs req.attrs.options, (err, data) ->
    return res.sendBack(err) if err
    res.columns data, {
      id: null,
      priority: ((p, item) -> "#{p}/#{item.severity}"),
      product: null,
      summary: null,
      status: ((_) -> "[#{_}]"),
      assigned_to: (_) -> " -> #{_}"
    }

app.receive 'update {commaSeparatedBugList} {{keyValuePairs}}', (req, res) ->
  req.session.bugzilla.update req.attrs.commaSeparatedBugList.split(","), req.attrs.keyValuePairs, res.ok

app.receive 'updateList {listOptions} {{keyValuePairs}}', (req, res) ->
  req.session.bugzilla.listBugs req.attrs.listOptions.split(" "), (err, data) ->
    return res.sendBack err if err
    return res.sendBack "No bugs to update :(" if data.length == 0
    req.session.bugzilla.update _.pluck(data, "id"), req.attrs.keyValuePairs, res.ok

app.receive 'create {{keyValuePairs}}', (req, res) ->
  req.session.bugzilla.create req.attrs.keyValuePairs, (err, data) ->
    res.sendBack err ? data

app.receive 'fieldsInfo', (req, res) ->
  req.session.bugzilla.getUpdateableFields (fields) -> res.sendBack fields

app.use transit.autohelp()

app.start()
