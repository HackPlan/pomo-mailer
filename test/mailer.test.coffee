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

    it 'send to nodemailer with cc support', ->
      mailer.sendMail('sample/sample', 'jysperm@gmail.com', name: 'world', {
        nodemailer: {
          cc: ["Yeechan Lu <orzfly@example.com>"]
        }
      }).catch ({message}) ->
        message.should.have.string 'To: jysperm@gmail.com'
        message.should.have.string 'Cc: Yeechan Lu <orzfly@example.com>'
        message.should.have.string '\r\n<p>Sample Email</p><p>Hello world</p>'

    it 'send to agent'

    it 'send to agent without template'

  describe 'sendMail with profiles', ->
    logs = []

    resetLogs = ->
      logs = []

    createTransport = (name) ->
      transport = stubTransport()
      transport.name = "#{name}Stub"
      transport.on 'end', (info) ->
        info.name = name
        logs.push info
      return transport

    mailer = new Mailer
      server: createTransport("default")
      from: 'Pomotodo <robot@pomotodo.com>'
      profiles:
        trigger: [{
          server: createTransport("trigger-domestic")
          match:
            type: "suffix"
            patterns: ["cn", "cn-example.com"]
        }]

        bulk: []

    describe 'profile "trigger"', ->
      it 'send to trigger-domestic with @cn-example.com', ->
        resetLogs()
        mailer.sendMail('sample/sample', 'test@cn-example.com', { name: 'world' }, { profile: 'trigger' }).catch ({message}) ->
          message.should.have.string '\r\n<p>Sample Email</p><p>Hello world</p>'
          logs.length.should.be.eql 1
          logs[0].name.should.be.eql 'trigger-domestic'

      it 'send to trigger-domestic with @example.cn', ->
        resetLogs()
        mailer.sendMail('sample/sample', 'test@example.cn', { name: 'world' }, { profile: 'trigger' }).catch ({message}) ->
          message.should.have.string '\r\n<p>Sample Email</p><p>Hello world</p>'
          logs.length.should.be.eql 1
          logs[0].name.should.be.eql 'trigger-domestic'

      it 'send to default with @example.com', ->
        resetLogs()
        mailer.sendMail('sample/sample', 'test@example.com', { name: 'world' }, { profile: 'trigger' }).catch ({message}) ->
          message.should.have.string '\r\n<p>Sample Email</p><p>Hello world</p>'
          logs.length.should.be.eql 1
          logs[0].name.should.be.eql 'default'

    describe 'profile "bulk"', ->
      it 'send to default with @example.cn', ->
        resetLogs()
        mailer.sendMail('sample/sample', 'test@example.cn', { name: 'world' }, { profile: 'bulk' }).catch ({message}) ->
          message.should.have.string '\r\n<p>Sample Email</p><p>Hello world</p>'
          logs.length.should.be.eql 1
          logs[0].name.should.be.eql 'default'