## pomo-mailer
Simple mailer with i18n and template engine.

## Sample
locale/en.json:

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
      languages: ['en', 'zh_CN']

    mailer.sendMail 'sample', 'jysperm@gmail.com',
      id: 'EM42'
    ,
      language: 'zh_TW'
      timezone: 'Asia/Shanghai'
    , (err) ->
      console.log arguments

## More Options

Mailer:

* `account` Same with nodemailer:

        {
          service: 'Postmark'
          auth:
            user: 'postmark-api-token'
            pass: 'postmark-api-token'
        }

* `send_from` Such as `Pomotodo <robot@pomotodo.com>`
* `default_template` jade or html(underscore), default to `jade`
* `reply_to` A email address
* `default_language` default to `en`
* `languages` A array of languages, default to `['en']`
* `strict_fallback` Don't fallback to incompatible language, default to `true`
* `template_prefix` default to `./template`
* `locale_prefix` default to `./locale`
* And other options same with nodemailer

mailer.sendMail:

    sendMail = (template_name, to_address, view_data, options, callback) ->

* `language`
* `timezone`
* And other options same with Mailer
* And other options same with nodemailer
