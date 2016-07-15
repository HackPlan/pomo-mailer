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

###
  Public: Render multi-language mail with template.
###
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
    else
      @mailer = @_createMailer @options.server

    @profiles = {}
    
    if _.isObject(@options.profiles)
      for profileName, profileConfig of @options.profiles
        @profiles[profileName] = profile =
          name: profileName
          mailers: []

        for config in profileConfig
          profile.mailers.push
            config: config
            mailer: @_createMailer(config.server || {})

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

    mailer = @mailer

    Q().then =>
      unless validator.isEmail address
        throw new Error 'Invalid email address ' + address

      if options?.profile && (profile = @profiles[options?.profile])
        @_doMatch(address, profile).then (result) ->
          mailer = result

    .then =>
      if !template
        if mailer.isPomoAgent and options.subject and (options.html or options.text)
          return {
            address: address
            options: defaultOptions()
          }
        else
          throw new Error 'Subject or content is empty without template'

      else if mailer.isPomoAgent and !mailer.render
        return {
          template: template
          address: address
          locals: locals
          options: defaultOptions()
        }

      else
        @render(template, locals, options).then (mail) ->
          return defaultOptions _.extend mail,
            to: address

    .then (mail) =>
      return Q.Promise (resolve, reject) =>
        mailer.sendMail mail, (err, res) ->
          if err
            reject err
          else if /^\s*250\b/.test res.response
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
        fs.read(filename).then (source) =>
          renderer = jade.compile source.toString(),
            filename: filename
          @templates_cache[template] = renderer
          return renderer
    .nodeify callback

  ###
    Private: Create mailer from config.
  ###
  _createMailer: (config) ->
    if config.service == 'PomoAgent'
      new PomoAgent config
    else
      nodemailer.createTransport config

  ###
    Private: Return a matched mailer
  ###

  _doMatch: (address, profile) ->
    for { config, mailer } in profile.mailers
      matcher = -> false

      if _.isFunction(config.match)
        matcher = config.match
      else if @_matchers[config.match.type]
        matcher = @_matchers[config.match.type]

      if matcher(address, config.match)
        return Q(mailer)

    return Q(@mailer)

  _matchers:
    suffix: (address, config) ->
      domain = getDomainPart(address)

      for pattern in config.patterns
        pat = pattern.toLowerCase()
        return true if domain == pat
        return true if domain.slice(-pat.length - 1) == "." + pat

      return false

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

getDomainPart = (address) ->
    address.substring(address.indexOf('@') + 1).toLowerCase()
