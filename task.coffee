{EventEmitter} = require 'events'
moment = require 'moment-timezone'
Mabolo = require 'mabolo'
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
      category: 1
      name: 1
      group_name: 1
    ,
      unique: true
      dropDups: true
    .done =>
      @triggerTask()
    , (err) =>
      @emit 'error', err,
        when: 'ensureIndex'

  ###
    Public: Stop task.
  ###
  stop: ->
    clearTimeout @timeoutId

  triggerTask: ->
    group = @groupBy()

    @TaskModel.findOne
      name: @name
      group: group
    .done (task) =>
      unless task
        @TaskModel.create
          name: name
          group: group
          progress_at: new Date()
        .done (task) =>
          @runTask task
        , (err) =>
          if err.message.match /duplicate/
            setImmediate @triggerTask
          else
            @emit 'error', err,
              when: 'createTask'
    , (err) =>
      @emit 'error', err,
        when: 'findTask'

    @resumeTasks()
    @waitNextGroup()

  runTask: (task) ->
    Q(@worker task).progress (progress) ->
      task.update
        $set:
          progress: progress
          progress_at: new Date()
      .catch (err) =>
        @emit 'error', err,
          when: 'updateProgress'
          task: task
          progress: progress
    .done =>
      task.update
        $set:
          finished_at: new Date()
      .catch (err) =>
        @emit 'error', err,
          when: 'finishTask'
          task: task
    , (err) =>
      @emit 'error', err,
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
      @runTask task
      @resumeTasks()
    , (err) =>
      @emit 'error', err,
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
