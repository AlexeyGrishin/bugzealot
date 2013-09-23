_ = require('underscore')
cradle = require('cradle')

class MemoryUsersStorage
  constructor: ->
    @_usersById = {}

  register: (id) ->
    @_usersById[id] = {}

  load: (id, cb) ->
    cb(null, @_usersById[id])

  put: (id, data) ->
    @_usersById[id] = _.extend({}, @_usersById[id], data)

  unregister: (id) ->
    delete @_usersById[id]

cid = (id) ->
  "client[#{id}]"

aid = (id) ->
  "aliases[#{id}]"

class CouchUsersStorage
  constructor: (options) ->
    @db = new(cradle.Connection)(options.url, options.port).database(options.database);

  register: (id) ->
    @db.get cid(id), (err) =>
      if (err)
        @db.save cid(id), {}, (err) ->
          console.error err if err

  load: (id, cb) ->
    @db.get cid(id), cb

  put: (id, data) ->
    @db.merge cid(id), data, (err) ->
      console.error err if err

  unregister: (id) ->
    @db.remove cid(id)

  loadAliases: (id, cb) ->
    @db.get aid(id), (err, res) ->
      cb res?.aliases ? []

  saveAliases: (id, aliases, cb = ->) ->
    @db.get aid(id), (err) =>
      if err
        @db.save aid(id), aliases: aliases, cb
      else
        @db.merge aid(id), aliases: aliases, cb


module.exports = CouchUsersStorage