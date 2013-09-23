xmlrpc = require('xmlrpc')
_ = require('underscore')

#TODO: user sessions
#TODO: obtain priorities/severities/statuses
class BugzillaClient
  constructor: (url) ->
    if url.indexOf("xmlrpc.cgi") == -1
      url = url + (if url[url.length-1] == "/" then "" else "/") + "xmlrpc.cgi";

    @client = xmlrpc.createClient({url: url, cookies: true});
    @user = null
    @fields = null
    @resultParsers = {}

  logout: (cb) ->
    @user = null
    cb()

  login: (username, password, cb) ->
    @_doCall "User.login", {
      login: username,
      password: password
    }, (err, res) =>
      cb(err, res)
      @user = username if not err

  _collectFields: (cb) ->
    @_doCall "Bug.fields", {}, (err, data) =>
      return cb(err) if err
      fields = {}
      findValues = (fieldName) =>
        fields[fieldName] = _.pluck (_.findWhere data.fields, {name: fieldName}).values, 'name'
      findValues 'priority'
      findValues 'bug_severity'
      findValues 'component'
      findValues 'bug_status'
      findValues 'resolution'
      @_doCall "Product.get_enterable_products", {}, (err, data) =>
        return cb(err) if err
        @_doCall "Product.get", data, (err, data) =>
          return cb(err) if err
          fields.product = _.pluck data.products, 'name'
          fields._names = _.keys fields
          fields.byValue = {}
          fields._values = []
          for field, values of fields
            continue if _.contains ['_names', 'byValue', '_values'], field
            fields.byValue[value] = field for value in values
            fields._values = fields._values.concat(values)
          @fields = fields
          cb()

  getBug: (bug, cb) ->
    @getBugs [bug], (err, result) ->
      return cb(err) if err
      return cb("Cannot find bug with id #{bug}") if result.length == 0
      cb(null, result[0])

  getBugs: (bugs, cb) ->
    return if @_notLoggedIn(cb)
    @_doCall "Bug.get", {
      ids: bugs
    }, (err, result) ->
      return cb(err) if err
      cb(null, result.bugs)

  listBugs: (options, cb) ->
    @_parseCriterias options, (err, criterias) =>
      return cb(err) if err
      @_doCall "Bug.search", criterias, (err, result) ->
        #cb(err, result ? {bugs:[]})
        cb(err, result?.bugs ? [])

  _parseCriterias: (options, cb) ->
    if not @fields
      return @_collectFields => @_parseCriterias(options, cb)
    criterias = {}
    checkAssigned = (value) =>
      if _.contains value, '@'
        criterias['assigned_to'] = value
        return true
      else if value == 'me'
        criterias['assigned_to'] = @user
        return true
      else
        false

    for value in options
      continue if checkAssigned(value)
      field = @fields.byValue[value]
      if not field
        possibleValues = @fields._values.filter((v) -> v.toLowerCase().indexOf(value.toLowerCase()) == 0)
        switch possibleValues.length
          when 0 then 0
          when 1
            value = possibleValues[0]
            field = @fields.byValue[value]
          else
            return cb("'#{value} is ambigous: #{possibleValues.join(',')}")

      return cb("'#{value}' is not valid value for any field: #{@fields._names}") if not field
      criterias[field] = value
    cb(null, criterias)

  _updateable: ['product', 'priority', 'bug_severity', 'version', 'component', 'summary', 'bug_status', 'resolution', 'assigned_to', 'comment']

  getFields: (cb) ->
    @_doCall "Bug.fields", {}, cb

  getUpdateableFields: (cb) ->
    cb @_updateable

  _convertBugFields: (fields) ->
    if _.isArray(fields)
      obj = {}
      fields.forEach (f) ->
        pair = f.split("=")
        obj[pair[0]] = pair.slice(1).join("=")
      fields = obj
    unknownKeys = _.difference(_.keys(fields), @_updateable)
    throw new Error("Do not know how to change these fields: #{unknownKeys.join(',')}") if unknownKeys.length > 0
    if fields.comment
      # Bugzilla requires hash here
      fields.comment = {comment: fields.comment}
    fields

  create: (fields, cb) ->
    fields = @_convertBugFields(fields)
    if fields.comment
      fields.description = fields.comment.comment
      delete fields.comment
    @_exposeArguments fields, (fields) =>
      @_doCall "Bug.create", fields, (err, res) ->
        return cb(err) if err
        cb null, res.id

  update: (bug, fields, cb) ->
    fields = @_convertBugFields(fields)
    bug = [bug] unless _.isArray(bug)
    fields.ids = bug
    @_exposeArguments fields, (fields) =>
      @_doCall "Bug.update", fields , cb

  _doCall: (method, params, callback) ->
    @client.methodCall method, [params], (err, body) ->
      #TODO: error handling
      callback(err?.faultString, body)

  _notLoggedIn: (cb) ->
    if not @user
      cb("Please login first with 'login' command")
      return true

  _exposeArguments: (args, cb) ->
    values = _.clone(args)
    for name, val of args
      switch val
        when "@user" then values[name] = @user
    cb(values)

  callAndReturnStatus: (method, args, callback) ->
    @call method, args, 'status', callback

  callAndReturnBug: (method, args, callback) ->
    @call method, args, 'bug', callback

  callAndReturnBugsList: (method, args, callback) ->
    @call method, args, 'buglist', callback

  #TODO: duplicate doCall?
  #TODO: delete at all
  call: (method, args, responseType, callback) ->
    return if @_notLoggedIn(callback)
    parseResult = @resultParsers[responseType]
    throw "Cannot find result parser for response type '#{responseType}'"
    @_exposeArguments args, (newArgs) =>
      @_doCall method, newArgs, (err, data) =>
        callback err, parseResult(data)

  close: ->

  @parseResponseOfType: (type, parser) ->
    @resultParsers[type] = parser

###
BugzillaClient.parseResponseOfType 'status', (data) ->
  if data then 'OK' else 'Error'

BugzillaClient.parseResponseOfType 'bug', (data) ->
  data?.bugs[0]

BugzillaClient.parseResponseOfType 'buglist', (data) ->
  data?.bugs ? []
###
module.exports = BugzillaClient