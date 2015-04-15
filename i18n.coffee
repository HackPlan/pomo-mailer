_ = require 'lodash'

###
  Public: Internationalization manager
###
module.exports = class I18n
  defaults:
    default: null

  @insert: (string, params) ->
    if _.isObject params
      for name, value of params
        string = string?.replace new RegExp("{#{name}}", 'g'), value

    return string

  ###
    Public: Constructor

    * `config` {Object}

      * `default` (optional) {String} Default language, e.g. `zh-CN`.

  ###
  constructor: (config) ->
    @config = _.defaults config, @defaults
    @translations = {}

  ###
    Public: Add translations.

    * `language` {String}
    * `translations` {Object}

  ###
  addTranslations: (language, translations) ->
    language = formatLanguage language
    @translations[language] ?= {}
    _.merge @translations[language], translations

  ###
    Public: Get all language names.

    Return {Array} of {String}.
  ###
  languages: ->
    return _.keys @translations

  ###
    Public: Create translator by language or request.

    * `language` {String} or {ClientRequest}
    * `prefixes` {Array} or {String}

    Return {Function} `(name, params) -> String`.
  ###
  translator: (language, prefixes) ->
    translator = (name, params) =>
      return I18n.insert @translate(name, @alternativeLanguages language), params

    return (name) ->
      for prefix in [prefixes..., name]
        fullName = "#{prefix}.#{name}"
        result = translator fullName, arguments[1 ..]...

        if result != fullName
          return result

      return name

  ###
    Public: Get packaged translations by language.

    * `language` {String}

    Return {Object}.
  ###
  translate: (name, languages) ->
    for language in languages
      result = @translateByLanguage name, language

      if result != undefined
        return result

    return name

  ###
    Private: Translate name by specified language.

    * `name` {String}
    * `language` {String}

    Return {String}.
  ###
  translateByLanguage: (name, language) ->
    return '' unless name

    ref = @translations

    for word in [language, name.split('.')...]
      if ref[word] == undefined
        return undefined
      else
        ref = ref[word]

    return ref

  ###
    Private: Get alternative languages of specified language.

    * `language` {String}

    Return {Array} of {String}.
  ###
  alternativeLanguages: (language) ->
    {lang} = parseLanguage language

    alternatives = @languages().filter (language) ->
      return parseLanguage(language).lang == lang

    return _.uniq _.compact [language, alternatives..., @config.default]

parseLanguage = (language) ->
  [lang, country] = language.replace('_', '-').split '-'

  return {
    lang: lang?.toLowerCase()
    country: country?.toUpperCase()
  }

formatLanguage = (language) ->
  {lang, country} = parseLanguage language
  return "#{lang}-#{country}"
