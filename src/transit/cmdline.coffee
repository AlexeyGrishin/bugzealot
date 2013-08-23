readline = require('readline')
rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

module.exports =
  install: (transit) ->
    transit.server @
  start: (options) ->
    rl.on 'line', (line) =>
      userId = line.substring(0, 1)
      line = line.substring(1).trim()
      if line == "exit"
        @callback user:userId, command:"exit", (err) ->
      else
        @callback user:userId, data:line, (err) ->
          console.error err if err
          rl.prompt()
    rl.prompt()
  receive: (@callback) ->
  sendBack: (userId, data, cb) ->
    console.log userId + ": " + data
    cb()