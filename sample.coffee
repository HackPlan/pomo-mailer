path = require 'path'
fs = require 'fs'
_ = require 'underscore'

mailer = require('pomo-mailer')
  account:
    service: 'Postmark'
    auth:
      user: 'postmark-api-token'
      pass: 'postmark-api-token'

  send_from: 'Pomotodo <robot@pomotodo.com>'
  languages: ['en', 'zh_CN']

mailer.sendMail 'sample', 'jysperm@gmail.com',
  id: 'EM42'
,
  language: 'zh_TW'
  timezone: 'Asia/Shanghai'
, (err) ->
  console.log arguments
