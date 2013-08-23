parser = require('../../src/transit/parser.coffee').parseCommand
parsePattern = require('../../src/transit/parser.coffee').parsePattern

s = (testFunc) ->
  (test) ->
    testFunc(test)
    test.done()

module.exports =
  testCommandWithoutArgs: s (test) ->
    {cmd, args} = parser "go"
    test.equal cmd, "go"
    test.deepEqual args, []

  testCommandWithArg: s (test) ->
    {cmd, args} = parser "go ahead"
    test.equal cmd, "go"
    test.deepEqual args, ["ahead"]

  testCommandWithQuotedArg: s (test) ->
    {cmd, args} = parser 'go "ahead"'
    test.equal cmd, "go"
    test.deepEqual args, ["ahead"]

  testCommand2Args: s (test) ->
    {cmd, args} = parser 'go home now'
    test.equal cmd, "go"
    test.deepEqual args, ["home", "now"]

  testCommandWithSpacedQuotedArg: s (test) ->
    {cmd, args} = parser 'go "home now"'
    test.equal cmd, "go"
    test.deepEqual args, ["home now"]

  testCommandSeveralArgs: s (test) ->
    {cmd, args} = parser 'one ring "to rule" "them all"'
    test.equal cmd, "one"
    test.deepEqual args, ["ring", "to rule", "them all"]

  testPattern: s (test) ->
    parsed = parsePattern "go {direction} {speed}"
    result = parsed.match "go", ["left", "quick"]
    test.ok(result)
    test.deepEqual result.args, {direction: "left", speed: "quick"}

  testPatternNoMatch: s (test) ->
    parsed = parsePattern "go {direction} {speed}"
    result = parsed.match "og", ["left", "fast"]
    test.ok(!result)

  testPatternRest: s (test) ->
    parsed = parsePattern "what {the} {{hell}}"
    result = parsed.match "what", ["is", "the", "main", "question"]
    test.deepEqual result.args, {the: "is", hell: ["the", "main", "question"]}


