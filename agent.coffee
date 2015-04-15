basicAuth = require 'basic-auth'

module.exports = class Agent
  constructor: ({@address, @users, @queue}) ->

  express: ->
    return (req, res) =>
      {name, pass} = basicAuth req

      unless @users[name] == pass
        return res.status(403).send 'Invalid Password'

      unless @address and req.ip in @address
        return res.status(403).send 'Address Forbidden'

      @queue.pushMail(req.body).done ->
        res.status(202).send 'Queued'
      , (err) ->
        res.status(400).send err.message
