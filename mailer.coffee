nodemailer = require 'nodemailer'
request = require 'request'
moment = require 'moment-timezone'
path = require 'path'
jade = require 'jade'
fs = require 'q-io/fs'
_ = require 'lodash'
Q = require 'q'

I18n = require './i18n'

module.exports = class Mailer
  defualts:
    account:
      service: 'Postmark'
      auth:
        user: 'postmark-api-token'
        pass: 'postmark-api-token'

    server:
      service: 'PomoAgent'
      server: 'http://127.0.0.1/agent'
      # TODO: Use basic auth
      token: '8a14c95f476a9b48'
      render: true

    from: 'Pomotodo <robot@pomotodo.com>'
    reply_to: 'Support <support@pomotodo.com>'

    templates: './template'
    locales: './locale'

    language: 'en'
    timezone: 'UTC'

    i18n:
      default: 'en'

    nodemailer: {}

    template_cache: true

  constructor: (options) ->
    @options = _.defaults options, @defualts
    @templates_cache = {}
    @i18n = new I18n @options.i18n

    if options.account.service == 'PomoAgent'
      @mailer = new PomoAgent @options.account
    else
      @mailer = nodemailer.createTransport @options.account

    @ready = fs.readdir(path.resolve @options.templates).then (filenames) =>
      for filename in filenames
        translations = require path.resolve @options.templates, filename
        @i18n.addTranslations path.basename(filename, '.json'), translations

  ###
    Public: Send mail.

    * `template`
    * `address`
    * `locals`
    * `options`
    * `callback` (optional) {Function}

    Return {Promise} resolve with response from server.
  ###
  sendMail: (template, address, locals, options, callback) ->
    @ready.then =>
      # TODO: No template
      if @mailer.isPomoAgent and !@mailer.render
        return {
          template: template
          address: address
          locals: locals
          options: options
        }
      else
        @render(template, locals, options).then (mail) ->
          {reply_to, from} = options

          return _.defaults mail, options.nodemailer,
            replyTo: reply_to
            from: from
    .then (mail) ->
      return Q.Promise (resolve, reject) ->
        mailer.sendMail mail, (err, res) ->
          if err
            reject err
          else if /^\s+250\b/.test res.response
            resolve res
          else
            reject new Error res.response
    .nodeify callback

  ###
    Public: Render mail.

    * `template` {String}
    * `locals` {Object}
    * `options` {Object}
    * `callback` (optional) {Function}

    Return {Promise} resolve with {subject, html, from, reply_to}.
  ###
  render: (template, locals, options, callback) ->
    {language, timezone, from, reply_to} = _.extend {}, @options, options

    @ready.then ->
      @resolve template
    .then (renderer) =>
      translator = @i18n.translator language, [template]

      html = renderer _.defaults locals,
        t: translator
        moment: ->
          return moment(arguments...).locale(language).tz(timezone)

      return {
        subject: translator "title.#{template}", locals
        html: html
        from: translator from, locals
        reply_to: translator reply_to, locals
      }
    .nodeify callback

  ###
    Public: Resolve renderer.

    * `template` {String}
    * `callback` (optional) {Function}

    return {Promise} resolve with {Function} `(locals) -> String`.
  ###
  resolve: (template, callback) ->
    Q.then =>
      if @templates_cache[template]
        return @templates_cache[template]
      else
        filename = path.resolve @options.templates, "#{template}.jade"

        fs.read(filename).then (source) ->
          return jade.compile source.toString(),
            filename: filename
    .nodeify callback

class PomoAgent
  isPomoAgent: true

  constructor: ({@server, @token, @render}) ->

  sendMail: (mail, callback) ->
    return Q.Promise (resolve, reject) =>
      request
        url: @server
        method: 'POST'
        headers:
          'X-Token': @token
        json: mail
      , (err, res, body) ->
        if err
          reject err
        else if ! (200 <= res.statusCode < 300)
          reject new Error res.test
        else
          resolve body
