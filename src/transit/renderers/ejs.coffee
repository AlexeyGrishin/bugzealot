fs = require('fs')
ejs = require('ejs')


module.exports = (options) ->
  ejsCache = {
    disable: options.disableCache ? false
  }
  withEjs = (templateName) ->
    (data) ->
      template = ejsCache[templateName]
      if not template
        template = fs.readFileSync("./ejs/#{templateName}.ejs", "utf-8")
        ejsCache[templateName] = template if not ejsCache.disable
      try
        ejs.render(template, data)
      catch e
        e.toString()
  withEjs
