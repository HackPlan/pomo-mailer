{EventEmitter} = require 'events'
Mabolo = require 'mabolo'
moment = require 'moment-timezone'
_ = require 'lodash'
Q = require 'q'

module.exports = class Task extends EventEmitter
  defaults:
    name: null
    worker: ->
    groupBy: ->

    mongodb: 'mongodb://localhost/pomo-mailer'
    timeout: 600 * 1000
    nextGroup: -> 3600 * 1000
    logger: console

  ###
    Event: `error`

    * `err` {Error}
    * `context` (optional) {Object}

  ###

  ###
    Public: Define a task.

    * `task` {Object}

      * `name` {String}
      * `mongodb` {String} Uri of MongoDB.
      * `groupBy` {Function} `-> String`.
      * `worker` {Function} `(task) -> Promise`
      * `timeout` (optional) {Number} Default `600 * 1000`.
      * `nextGroup` (optional) {Function} `-> Number|Date|Moment`, default `-> 3600 * 1000`.
      * `logger` (optional) {Object} Default `console`

  ###
  constructor: (options) ->
    _.extend @, _.defaults options, @defualts

    @mabolo = new Mabolo @mongodb

    @TaskModel = @mabolo.model 'Task',
      name:
        type: String
        required: true

      group:
        type: String
        required: true

      progress: Object
      progress_at: Date
      finished_at: Date

    @TaskModel.ensureIndex
      name: 1
      group: 1
    ,
      unique: true
      dropDups: true
    .done =>
      @triggerTask()
    , (err) =>
      @emit 'error', _.extend err,
        context:
          when: 'createTask'

    @on 'error', (err) =>
      @logger?.log err, err.context

  ###
    Public: Stop task.
  ###
  stop: ->
    clearTimeout @timeoutId
    @stopped = true

  triggerTask: ->
    group = @groupBy()

    @TaskModel.findOne
      name: @name
      group: group
    .done (task) =>
      unless task
        @TaskModel.create
          name: @name
          group: group
          progress_at: new Date()
        .done (task) =>
          @runTask task
        , (err) =>
          if err.message.match /duplicate/
            setImmediate @triggerTask.bind(@)
          else
            @emit 'error', _.extend err,
              context:
                when: 'createTask'
    , (err) =>
      @emit 'error', err,
        when: 'findTask'

    @resumeTasks()
    @waitNextGroup()

  runTask: (task) ->
    if @stopped
      return

    Q(@worker task).progress (progress) ->
      task.update
        $set:
          progress: progress
          progress_at: new Date()
      .catch (err) =>
        @emit 'error', _.extend err,
          context:
            when: 'updateProgress'
            task: task
            progress: progress
    .done =>
      task.update
        $set:
          finished_at: new Date()
      .catch (err) =>
        @emit 'error', err,
          context:
            when: 'finishTask'
            task: task
    , (err) =>
      @emit 'error', err,
        context:
          when: 'runTask'
          task: task

  resumeTasks: ->
    @TaskModel.findOneAndUpdate
      name: @name
      finished_at:
        $exists: false
      progress_at:
        $lt: new Date Date.now() - @timeout
    ,
      $set:
        progress_at: new Date()
    .done (task) =>
      if task
        @runTask task
        @resumeTasks()
    , (err) =>
      @emit 'error', err,
        context:
          when: 'resumeTasks'

  waitNextGroup: ->
    next = @nextGroup()

    if moment.isMoment next
      next = next.toDate()

    if _.isDate next
      interval = next.getTime() - Date.now()
    else
      interval = next

    @timeoutId = setTimeout =>
      @triggerTask()
    , interval
