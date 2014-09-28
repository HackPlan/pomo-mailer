## pomo-mailer
Simple mailer with i18n and template engine.

## Sample
locale/en_US.json:

    {
      "email_title": {
        "sample-jade": "[__id__] Sample Email"
      },
      "welcome": "Hello, World"
    }

template/sample.jade:

    h1= t('email_title.sample-jade', {id: id})
    p= t('welcome')
    hr
    p= id

sample.coffee:

    mailer = require('pomo-mailer')
      account:
        service: 'Postmark'
        auth:
          user: 'postmark-api-token'
          pass: 'postmark-api-token'

      send_from: 'Pomotodo <robot@pomotodo.com>'

      default_template: 'jade'

      default_language: 'en_US'
      languages: ['en_US', 'zh_CN']

      template_prefix: "#{__dirname}/template"
      locale_prefix: "#{__dirname}/locale"

    mailer.sendMail 'sample', 'jysperm@gmail.com',
      id: 'EM42'
    ,
      language: 'zh_TW'
      timezone: 'Asia/Shanghai'
    , (err) ->
      console.log arguments
