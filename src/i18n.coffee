_ = require 'lodash'
dottie = require 'dottie'

###
  Public: Internationalization utils.
###
module.exports = class I18n
  defaults:
    default: null

  @insert: (string, params) ->
    replace_matchs = _.uniq string.match(/{(.+?)}/g)
    for replace_match in replace_matchs
      variable_match = /{(.+?)}/g.exec(replace_match)
      if variable_match
        value = dottie.get params, variable_match[1]
        if value
          string = string.replace replace_match, value
    return string

  ###
    Public: Constructor

    * `options` (optional) {Object}

      * `default` (optional) {String} Default language, e.g. `zh-CN`.

  ###
  constructor: (options) ->
    @options = _.defaults {}, options, @defaults
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

    * `language` {String}
    * `prefixes` (optional) {Array} or {String}

    Return {Function} `(name, params) -> String`.
  ###
  translator: (language, prefixes = []) ->
    translator = (name, params) =>
      return I18n.insert @translate(name, @alternativeLanguages language), params

    return (name) ->
      for prefix in [prefixes..., null]
        if prefix
          full_name = "#{prefix}.#{name}"
        else
          full_name = name

        result = translator full_name, [arguments...][1 ..]...

        if result != full_name
          return result

      return name

  ###
    Public: Translate name by languages.

    * `name` {String}
    * `languages` {Array} of {String}

    Return {String}.
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
    return name unless name

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

    return _.uniq _.compact [language, alternatives..., @options.default]

parseLanguage = (language) ->
  unless language
    return {
      lang: undefined
      country: undefined
    }

  [lang, country] = language.replace('_', '-').split '-'

  return {
    lang: lang?.toLowerCase()
    country: country?.toUpperCase()
  }

formatLanguage = (language) ->
  {lang, country} = parseLanguage language

  if country
    return "#{lang}-#{country}"
  else
    return lang
