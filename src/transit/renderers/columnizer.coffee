columnizer = require('columnizer')
_ = require('underscore')

withColumns = (fields) ->
  printItem = (col, item) ->
    col.row.apply col, _.keys(fields).map((name) ->
      render = (fields[name] ? (s) -> s)
      render item[name], item
    )
  printCollection = (collection) ->
    return printCollection [collection] if not _.isArray collection
    col = new columnizer()
    collection.forEach printItem.bind(null, col)
    col._toString(3)

  printCollection

module.exports = () -> withColumns