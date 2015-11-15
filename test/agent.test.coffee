bodyParser = require 'body-parser'
supertest = require 'supertest'
express = require 'express'

{Agent, Queue} = pomoMailer

describe 'agent', ->
  describe 'express', ->
    mails = []
    app = express()

    before ->
      queue = new Queue
        mailer: mockMailer mails
        mongodb: mongodb_uri

      agent = new Agent
        queue: queue
        users:
          jysperm: 'pass'

      app.use bodyParser.json()
      app.use agent.express()

      queue.QueueModel.remove()

    it 'should success', (done) ->
      supertest app
      .post '/'
      .send
        locals: name: 'agent'
        address: 'jysperm@gmail.com'
      .auth 'jysperm', 'pass'
      .expect 202
      .end done

    it 'should forbidden', (done) ->
      supertest app
      .post '/'
      .send
        locals: name: 'agent'
        address: 'jysperm@gmail.com'
      .expect 403
      .end done

    after ->
      Q.delay(50).then ->
        mails.length.should.be.equal 1
        mails[0].locals.name.should.be.equal 'agent'
