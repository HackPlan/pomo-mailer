nodemailer = require 'nodemailer'
validator = require 'validator'
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
    server:
      service: 'Postmark'
      auth:
        user: 'postmark-api-token'
        pass: 'postmark-api-token'

    from: 'Pomotodo <robot@pomotodo.com>'

    templates: './template'
    locales: './locale'

    timezone: 'UTC'

    i18n:
      default: 'en'

    nodemailer: {}

    template_cache: true

  ###
    Public: Constructor

    * `options` {Object}

      * `server` {Object} One of:

        * Options pass to nodemailer-smtp-transport
        * {Object}

          * `service` {String} `PomoAgent`.
          * `host` {String} Url of {Agent}.
          * `auth` {Object} Basic auth of {Agent}.
          * `render` (optional) {Boolean} Render template.

      * `from` (optional) {String} Send from address, accept i18n string.
      * `replyTo` (optional) {String} Reply to address, accept i18n string, e.g. `'Support <support@pomotodo.com>'`.
      * `templates` (options) {String} Template directory.
      * `locales` (options) {String} Locales directory.
      * `timezone` (options) {String} Default timezone.
      * `i18n` (optional) {Object} Options pass to {I18n}.
      * `nodemailer` (optional) {Object} Default options pass to nodemailer.
      * `template_cache` (optional) {Boolean} Enable template cache.

  ###
  constructor: (options) ->
    @options = _.defaults {}, options, @defualts
    @templates_cache = {}
    @i18n = new I18n @options.i18n

    if !options?.server
      console.log 'Warning: Required options.server'
    else if options.server.service == 'PomoAgent'
      @mailer = new PomoAgent @options.server
    else
      @mailer = nodemailer.createTransport @options.server

    @ready = fs.list(path.resolve @options.locales).then (filenames) =>
      for filename in filenames
        translations = require path.resolve @options.locales, filename
        @i18n.addTranslations path.basename(filename, '.json'), translations

  ###
    Public: Send mail.

    * `template` (optional) {String} Template name.
    * `address` {String} To address.
    * `locals` (optional) {Object} Options pass to template.
    * `options` (optional) {Object} Overwrite {Mailer} options.
    * `callback` (optional) {Function}

    Return {Promise} resolve with response from server.
  ###
  sendMail: (template, address, locals, options, callback) ->
    defaultOptions = (explicit) =>
      return _.defaults {}, explicit, options?.nodemailer, @options.nodemailer

    Q().then =>
      unless validator.isEmail address
        throw new Error 'Invalid email address ' + address

      if !template
        if @mailer.isPomoAgent and options.subject and (options.html or options.text)
          return {
            address: address
            options: defaultOptions()
          }
        else
          throw new Error 'Subject or content is empty without template'

      else if @mailer.isPomoAgent and !@mailer.render
        return {
          template: template
          address: address
          locals: locals
          options: defaultOptions()
        }

      else
        @render(template, locals, options).then (mail) ->
          return defaultOptions mail

    .then (mail) =>
      return Q.Promise (resolve, reject) =>
        @mailer.sendMail mail, (err, res) ->
          if err
            reject err
          else if /^\s+250\b/.test res.response
            resolve res
          else
            reject new Error res.response

    .nodeify callback

  ###
    Public: Render mail.

    * `template` {String} Template name.
    * `locals` (optional) {Object} Options pass to template.
    * `options` (optional) {Object} Overwrite {Mailer} options.
    * `callback` (optional) {Function}

    Return {Promise} resolve with {subject, html, from, replyTo}.
  ###
  render: (template, locals, options, callback) ->
    {language, timezone, from, replyTo, subject} = _.defaults {}, options, @options

    @resolve(template).then (renderer) =>
      translator = @i18n.translator language, [template]

      mail = {
        subject: translator (subject ? "#{template.replace /\//g, '.'}.title"), locals
        from: translator from, locals
      }

      if replyTo
        mail.replyTo = translator replyTo, locals

      html = renderer _.defaults {}, locals,
        t: translator
        meta: mail
        moment: ->
          return moment(arguments...).locale(language).tz(timezone)

      return _.extend mail,
        html: html

    .nodeify callback

  ###
    Public: Resolve renderer.

    * `template` {String} Template name.
    * `callback` (optional) {Function}

    return {Promise} resolve with {Function} `(locals) -> String`.
  ###
  resolve: (template, callback) ->
    @ready.then =>
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

  constructor: ({@host, @auth}) ->

  sendMail: (mail, callback) ->
    return Q.Promise (resolve, reject) =>
      request
        url: @host
        method: 'POST'
        auth: @auth
        json: mail
      , (err, res, body) ->
        if err
          reject err
        else if ! (200 <= res.statusCode < 300)
          reject new Error body
        else
          resolve body
