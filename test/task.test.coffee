Mabolo = require 'mabolo'

{Task} = pomoMailer

describe 'task', ->
  describe 'triggerTask', ->
    task = null
    times = 0

    before ->
      mabolo = new Mabolo mongodb_uri
      TaskModel = mabolo.model 'Task', {}
      TaskModel.remove()

    it '10 ms * 3 times', (done) ->
      task = new Task
        name: 'sample'
        mongodb: mongodb_uri
        groupBy: -> (new Date().getMilliseconds() / 10).toFixed()
        nextGroup: -> 5
        worker: ->
          times += 1

          if times >= 3
            task.stop()
            done()

    it 'should be stopped', ->
      Q.delay(50).then ->
        times.should.be.equal 3
