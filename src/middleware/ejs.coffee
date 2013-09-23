fs = require('fs')
ejs = require('ejs')

module.exports = (options) ->
  ejsCache = {
    disable: options.disableCache ? false
  }
  (data, options, next) ->
    templateName = if typeof options is "string" then options else options.ejs
    template = ejsCache[templateName]
    if not template
      template = fs.readFileSync("./ejs/#{templateName}.ejs", "utf-8")
      ejsCache[templateName] = template if not ejsCache.disable
    try
      next ejs.render(template, data)
    catch e
      next e.toString()

