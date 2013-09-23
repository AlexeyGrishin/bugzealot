columnizer = require('columnizer')
_ = require('underscore')

DEFAULT_RENDER = (s) -> s

module.exports = (maxWidth) ->

  printCollection = (data, options, next) ->
    return printCollection [data], options, next if not _.isArray data

    fields = options.columns ? options
    printItem = (col, item) ->
      col.row.apply col, _.keys(fields).map((name) ->
        render = DEFAULT_RENDER
        render = fields[name] if _.isFunction(fields[name])
        render item[name], item
      )

    col = new columnizer()
    data.forEach printItem.bind(null, col)
    next col.toString(3, false, maxWidth)

  printCollection