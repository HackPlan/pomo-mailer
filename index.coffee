nodemailer = require 'nodemailer'
moment = require 'moment-timezone'
path = require 'path'
jade = require 'jade'
fs = require 'fs'
_ = require 'underscore'

default_options =
  account:
    service: 'Postmark'
    auth:
      user: 'postmark-api-token'
      pass: 'postmark-api-token'

  send_from: 'Pomotodo <robot@pomotodo.com>'
  #reply_to: 'support@pomotodo.com'

  default_template: 'jade'

  default_language: 'en'
  languages: ['en', 'zh_CN', 'zh_TW', 'jp']

  template_prefix: "./template"
  locale_prefix: "./locale"

parseLanguageCode = (original_language) ->
  language = original_language.toLowerCase().replace '-', '_'
  [lang, country] = language.split '_'

  return {
    original: original_language
    language: language
    lang: lang
    country: country
  }

module.exports = (mailer_options) ->
  mailer_options = _.extend _.clone(default_options), mailer_options
  mailer_options.language_infos = _.map mailer_options.languages, parseLanguageCode

  mailer = nodemailer.createTransport mailer_options.account

  i18n_data = {}
  template_cache = {}
  priority_cache = {}

  for language_info in mailer_options.language_infos
    i18n_data[language_info.language] = require "#{mailer_options.locale_prefix}/#{language_info.original}.json"

  is_found_default_language = _.find mailer_options.language_infos, (language_info) ->
    return language_info.language == parseLanguageCode(mailer_options.default_language).language

  unless is_found_default_language
    throw new Error 'Default language not found in locale directory'

  calcLanguagePriority = (language) ->
    language_info = parseLanguageCode language

    result = []

    result = result.concat _.filter mailer_options.language_infos, (i) ->
      return i.language == language_info.language

    result = result.concat _.filter mailer_options.language_infos, (i) ->
      return i.lang == language_info.lang

    result.push parseLanguageCode mailer_options.default_language

    result = result.concat mailer_options.language_infos

    return _.uniq _.pluck result, 'language'

  getLanguagePriority = (language) ->
    if priority_cache[language]
      return priority_cache[language]

    priority_data = calcLanguagePriority language
    priority_cache[language] = priority_data

    return priority_data

  translateByLanguage = (name, language) ->
    keys = name.split '.'
    keys.unshift language

    result = i18n_data

    for item in keys
      if result[item] == undefined
        return undefined
      else
        result = result[item]

    return result

  translate = (name, preferred_language) ->
    priority_data = getLanguagePriority preferred_language

    for language in priority_data
      result = translateByLanguage name, language

      if result != undefined
        return result

    return name

  getTemplateInfo = (template_name) ->
    unless path.extname template_name
      template_name += ".#{mailer_options.default_template}"

    engine = path.extname(template_name).replace '.', ''
    file_path = path.join mailer_options.template_prefix, template_name

    return {
      engine: engine
      file_name: template_name
      file_path: file_path
    }

  getTemplate = (template_file, callback) ->
    if template_cache[template_file]
      return callback null, template_cache[template_file]

    fs.readFile template_file, (err, template_source) ->
      callback err, template_source.toString()

  renderTemplate = (engine, template_source, view_data) ->
    if engine == 'jade'
      return jade.render template_source, view_data

    else if engine == 'html'
      return _.template(template_source) view_data

    else
      throw new Error 'Unknown Engine'

  return {
    i18n: (options) ->
      return  (name, payload) ->
        result = translate name, options.language

        if _.isObject payload
          for k, v of payload
            result = result.replace "__#{k}__", v

        return result

    moment: (options) ->
      return ->
        return moment.apply(@, arguments).locale(options.language).tz(options.timezone)

    sendMail: (template_name, to_address, view_data, options, callback) ->
      options = _.extend _.clone(mailer_options), options

      t = @i18n options
      m = @moment options

      {engine, file_path, file_name} = getTemplateInfo template_name

      getTemplate file_path, (err, template_source) ->
        return callback err if err

        mail_body = renderTemplate engine, template_source, _.extend({t: t, m: m}, view_data)

        options = _.extend options,
          from: options.send_from
          to: to_address
          subject: t "email_title.#{file_name.replace('.', '-')}", view_data
          html: mail_body
          replyTo: options.reply_to

        mailer.sendMail options, (err, info) ->
          if err
            callback err
          else if /^\s+250\b/.test info.response
            callback new Error 'Unknown Error'
          else
            callback err, info

  }
