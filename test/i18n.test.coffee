{I18n} = pomoMailer

describe 'i18n', ->
  describe 'translations', ->
    it 'add translations in same language', ->
      i18n = new I18n()

      i18n.addTranslations 'en',
        hello: 'hello'
        world: 'world'

        email:
          title: 'Email Title'

      i18n.addTranslations 'en',
        email:
          body: 'Email Body'

      i18n.addTranslations 'en',
        hello: 'Hello'
        mail: 'Mail'

      i18n.translations.should.be.eql
        en:
          hello: 'Hello'
          world: 'world'
          mail: 'Mail'

          email:
            title: 'Email Title'
            body: 'Email Body'

    it 'add translations in multi-language', ->
      i18n = new I18n()

      i18n.addTranslations 'en-', hello: 'hello'
      i18n.addTranslations 'en_US', hello: 'hello'
      i18n.addTranslations 'zh-CN', hello: '你好'
      i18n.addTranslations 'ZH_cn', world: '世界'

      i18n.translations.should.be.eql
        en:
          hello: 'hello'
        'en-US':
          hello: 'hello'
        'zh-CN':
          hello: '你好'
          world: '世界'

  describe 'translate', ->
    i18n = null

    before ->
      i18n = new I18n()
      addTranslations i18n

    it 'translate in specified language', ->
      test = (name, language, result) ->
        expect(i18n.translateByLanguage name, language).to.be.equal result

      test '', 'en', undefined
      test null, 'en', undefined
      test 'hello', 'zh-TW', undefined
      test 'email.title', 'zh-CN', undefined
      test 'hello', 'en', 'Hello'
      test 'hello', 'zh-CN', '你好'
      test 'email.title', 'en', 'Email Title'

    it 'translate in languages', ->
      test = (name, languages, result) ->
        expect(i18n.translate name, languages).to.be.equal result

      test '', ['en', 'zh-CN'], ''
      test 'hello.world', ['en', 'zh-CN'], 'hello.world'
      test 'email.from', ['en', 'zh-CN'], 'email.from'
      test 'hello', ['zh-TW'], 'hello'
      test 'hello', ['en', 'zh-CN'], 'Hello'
      test 'hello', ['zh-CN', 'en'], '你好'
      test 'world', ['en-US', 'en', 'zh-CN'], '世界'

  describe 'alternative languages', ->
    test = (i18n, language, languages) ->
      expect(i18n.alternativeLanguages language).to.be.eql languages

    it 'alternative language', ->
      i18n = new I18n()
      addLanguages i18n, ['en', 'en-US']

      test i18n, 'en', ['en', 'en-US']
      test i18n, 'en-US', ['en-US', 'en']

      i18n = new I18n()
      addLanguages i18n, ['zh-CN', 'zh-TW', 'zh', 'en']

      test i18n, 'en', ['en']
      test i18n, 'zh-TW', ['zh-TW', 'zh-CN', 'zh']

    it 'with default language', ->
      i18n = new I18n default: 'zh-CN'
      addLanguages i18n, ['zh-CN', 'zh-TW', 'zh', 'en']

      test i18n, 'en', ['en', 'zh-CN']
      test i18n, 'zh-TW', ['zh-TW', 'zh-CN', 'zh']
      test i18n, 'fr', ['fr', 'zh-CN']

  describe 'translator', ->
    i18n = null

    beforeEach ->
      i18n = new I18n()
      addTranslations i18n

    it 'basic translator', ->
      t = i18n.translator 'en'

      t('hello').should.be.equal 'Hello'
      t('email.title').should.be.equal 'Email Title'

    it 'language fallback', ->
      t = i18n.translator 'en-US'

      t('hello').should.be.equal 'Hello'
      t('email.title').should.be.equal 'Email Title'

    it 'insert parameter', ->
      t = i18n.translator 'en'

      t('email.body').should.be.equal 'Email to {to}'
      t('email.body', to: 'jysperm').should.be.equal 'Email to jysperm'

    it 'with prefixes', ->
      t = i18n.translator 'en', ['email']

      t('title').should.be.equal 'Email Title'
      t('email.title').should.be.equal 'Email Title'
      t('hello').should.be.equal 'Hello'
      t('email.from').should.be.equal 'email.from'

addTranslations = (i18n) ->
  i18n.addTranslations 'en',
    hello: 'Hello'

    email:
      title: 'Email Title'
      body: 'Email to {to}'

  i18n.addTranslations 'en-US',
    hello: 'Hello'

  i18n.addTranslations 'zh-CN',
    hello: '你好'
    world: '世界'

addLanguages = (i18n, languages) ->
  for language in languages
    i18n.addTranslations language, {}
