BugzillaClient = require('./bugzilla')
async = require('async')

client = new BugzillaClient "http://192.168.56.101:80"

output = (name, data) ->
  console.log "-#{name}------------"
  console.log JSON.stringify(data, null, 2).split("\n").map((s) -> "  " + s).join("\n")
  console.log "--------------------"

summary = null
async.waterfall [
  (cb) ->
    client.login "alexey.grishin@gmail.com", "qwerty!!!1", cb
  (res, cb) ->
    output "login", "DONE"
    client.getBug 2, cb
  (bug, cb) ->
    output "getBug", bug
    summary = bug.summary
    client.listBugs ["CONFIRMED", "Product2"], cb
  (bugs, cb) ->
    output "listBugs", bugs
    client.getFields cb
  (fields, cb) ->
    output "fields", fields
    client.update 2, ["summary=#{summary}!","assigned_to=@user", "comment=111"], cb
  (res, cb) ->
    output "save", res
    client.create ["summary=New", "product=Product2", "component=Comp1", "version=unspecified", "comment=Just new bug"], cb
  (res, cb) ->
    output "after creation", res
    client.logout cb
], (err) ->
  if err
    console.error "Error!"
    console.error err