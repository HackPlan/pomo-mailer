nodemailer = require 'nodemailer'
_ = require 'underscore'

default_options =
  account:
    service: 'Postmark'
    auth:
      user: 'postmark-api-token'
      pass: 'postmark-api-token'

  send_from: 'Pomotodo <robot@pomotodo.com>'
  reply_to: 'support@pomotodo.com'

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

  return {
    sendMail: (template_name, to_address, view_data, i18n_options, callback) ->

  }
