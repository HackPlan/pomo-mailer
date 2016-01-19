basicAuth = require 'basic-auth'

###
  Public: Mail agent using HTTP API, Connect {Mailer} and {Queue}.
###
module.exports = class Agent
  ###
    Public: Constructor

    * `options` {Object}

      * `queue` {Queue}
      * `users` {Object} User as key, password as value.
      * `address` (optional) {Array} of {String}

  ###
  constructor: ({@address, @users, @queue}) ->

  express: ->
    return (req, res, next) =>
      {name, pass} = basicAuth(req) ? {}

      unless name and @users[name] == pass
        return res.status(403).send 'Invalid Password'

      unless !@address or req.ip in @address
        return res.status(403).send 'Address Forbidden'

      @queue.pushMail(req.body).done ->
        res.status(202).send 'Queued'
      , next
