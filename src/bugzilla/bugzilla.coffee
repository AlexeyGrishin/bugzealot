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
    @options = {
      completedInDev: "CONFIRMED"
    }

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
    return if @_notLoggedIn(cb)
    @_doCall "Bug.get", {
      ids: bug
    }, (err, result) ->
      return cb(err) if err
      return cb("Cannot find bug with id #{bug}") if result.bugs.length == 0
      cb(null, result.bugs[0])

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

  getFields: (cb) ->
    @_doCall "Bug.fields", {}, cb

  takeBug: (bug, cb) ->
    return if @_notLoggedIn(cb)
    @update bug, {
      assigned_to: @user
    }, cb

  completeBug: (bug, cb) ->
    return if @_notLoggedIn(cb)
    @update bug, {
      status: @options.completedInDev
    }, cb

  update: (bug, data, cb) ->
    data.ids = bug
    @_doCall "Bug.update", data, cb

  _doCall: (method, params, callback) ->
    @client.methodCall method, [params], (err, body) ->
      #TODO: error handling
      callback(err, body)

  _notLoggedIn: (cb) ->
    if not @user
      cb("Please login first with 'login' command")
      return true

  close: ->



module.exports = BugzillaClient