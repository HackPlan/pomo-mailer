stubTransport = require 'nodemailer-stub-transport'

{Mailer} = pomoMailer

describe 'mailer', ->
  describe 'render', ->
    it 'with locals', ->
      mailer = new Mailer
        server: {}
        from: 'robot@pomotodo.com'

      mailer.render('sample/sample', name: 'world').then (mail) ->
        mail.should.be.eql
          subject: 'Sample Email'
          from: 'robot@pomotodo.com'
          html: '<p>Sample Email</p><p>Hello world</p>'

    it 'meta fields', ->
      mailer = new Mailer
        server: {}
        from: 'from'

      mailer.render('sample/sample', name: 'world').then (mail) ->
        mail.from.should.be.eql 'Pomotodo <robot@pomotodo.com>'

    it 'default language', ->
      mailer = new Mailer
        server: {}
        i18n:
          default: 'zh-CN'

      mailer.render('sample/sample', name: 'world').then (mail) ->
        mail.subject.should.be.eql '示例邮件'

    it 'translator and moment'

  describe 'sendMail', ->
    mailer = new Mailer
      server: stubTransport()
      from: 'Pomotodo <robot@pomotodo.com>'

    it 'send to nodemailer', ->
      mailer.sendMail('sample/sample', 'jysperm@gmail.com', name: 'world').catch ({message}) ->
        message.should.have.string 'Content-Type: text/html'
        message.should.have.string 'From: Pomotodo <robot@pomotodo.com>'
        message.should.have.string 'Subject: Sample Email'
        message.should.have.string '\r\n<p>Sample Email</p><p>Hello world</p>'

    it 'send to agent'

    it 'send to agent without template'
