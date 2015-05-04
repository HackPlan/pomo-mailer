_ = require 'lodash'
Q = require 'q'

{Queue} = pomoMailer

describe 'queue', ->
  mails = []
  QueueModel = null
  mailer = null
  queue = null

  before ->
    mailer = mockMailer mails

    queue = new Queue
      mailer: mailer
      mongodb: 'mongodb://localhost/pomo-mailer-test'

  before ->
    {QueueModel} = queue
    QueueModel.remove()

  describe 'pushMail', ->
    it 'push simple mail', ->
      queue.pushMail
        address: 'jysperm@gmail.com'

    it 'push mail with template', ->
      queue.pushMail
        template: 'sample/sample'
        address: 'jysperm@gmail.com'
        locals:
          name: 'world'

    after ->
      Q().then ->
        mails[0].address.should.be.equal 'jysperm@gmail.com'
        mails[1].template.should.be.equal 'sample/sample'

  describe 'fetchMail', ->
    before ->
      QueueModel.remove().then ->
        QueueModel.create
          unique_id: 'apple'
          address: 'jysperm@gmail.com'
          created_at: new Date()

    it 'fetch a mail', ->
      queue.fetchMail().then (mail) ->
        mail.unique_id.should.be.equal 'apple'

        QueueModel.findOne(unique_id: 'apple').then (mail) ->
          mail.started_at.should.be.exists

    it 'fetch mail again', ->
      queue.fetchMail().then (mail) ->
        expect(mail).to.not.exists

mockMailer = (storage) ->
  return {
    sendMail: (template, address, locals, options) ->
      storage.push {template, address, locals, options}
      return Q()
  }
