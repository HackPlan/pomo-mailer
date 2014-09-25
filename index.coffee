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

parseLanguageCode = (language) ->
  language = language.toLowerCase().replace '-', '_'
  [lang, country] = language.split '_'

  return {
    language: language
    lang: lang
    country: country
  }

module.exports = (options) ->
  options = _.extend default_options, options
  options.languages = _.map options.languages, parseLanguageCode

  mailer = nodemailer.createTransport options.account

  i18n_data = {}
  priority_cache = {}

  for language in options.languages
    i18n_data[language] = require "#{options.locale_prefix}/#{language}.json"

  calcLanguagePriority = (language) ->
    language = parseLanguageCode language

    result = []

    result.concat _.filter options.languages, (i) ->
      return i.language == language.language

    result.concat _.filter options.languages, (i) ->
      return i.lang == language.lang

    result.push options.default_language

    result.concat options.languages

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
      template_name += ".#{options.default_template}"

    engine = path.extname template_name
    file_path = path.join options.template_prefix, template_name

    return {
      engine: engine
      file_name: template_name
      file_path: file_path
    }

  renderTemplate = (template_name, view_data, callback) ->
    {engine, file_path} = getTemplateInfo template_name

    if engine == 'jade'
      jade.renderFile file_path, view_data, (err, content) ->
        callback err, content

    else if engine == 'html'
      fs.readFile file_path, (err, content) ->
        return callback err if err
        content = _.template(content) view_data
        callback null, content

    else
      callback new Error 'Unknown Engine'

  return {
    sendMail: (template_name, to_address, view_data, i18n_options, callback) ->
      t = (name) ->
        return translate name, i18n_options.language

      m = ->
        return moment.apply(@, arguments).locale(language).tz(i18n_options.timezone)

      renderTemplate template_name, _.extend({t: t, m: m}, view_data), (err, mail_body) ->
        {file_name} = getTemplateInfo template_name

        mailer.sendMail
          from: options.send_from
          to: to_address
          subject: t "email_title.#{file_name}"
          html: mail_body
          reply_to: options.reply_to
        , (err) ->
          callback err
  }
