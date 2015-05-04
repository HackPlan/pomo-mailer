process.env.NODE_ENV = 'test'

chai = require 'chai'
_ = require 'lodash'
Q = require 'q'

_.extend global,
  mongodb_uri: 'mongodb://localhost/pomo-mailer-test'
  pomoMailer: require '../index'
  expect: chai.expect
  Q: Q
  _: _

chai.should()
chai.config.includeStack = true

global.mockMailer = (storage) ->
  return {
    sendMail: (template, address, locals, options) ->
      storage.push {template, address, locals, options}
      return Q()
  }
