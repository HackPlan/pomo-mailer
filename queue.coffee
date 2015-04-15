{EventEmitter} = require 'events'
moment = require 'moment-timezone'
async = require 'async-q'
_ = require 'lodash'
Q = require 'q'

module.exports = class Queue extends EventEmitter
  defaults:
    mongodb: 'mongodb://localhost/pomo-mailer'
    mailer: null

    timeout: 60 * 1000
    delay: 60 * 1000
    threads: 5

    local_time_start: 8
    local_time_end: 16

    logger: console

  constructor: (options) ->
    @options = _.defaults options, @defualts
    @mailer = @options.mailer

    @mabolo = new Mabolo @mongodb

    @QueueModel = @mabolo.model 'Queue',
      address:
        type: String
        required: true

      created_at:
        type: Date
        required: true

      unique_id: String
      template: String
      locals: Object
      options: Object

      started_at: Date
      finished_at: Date

      response: Object

    @ready = Q.all [
      @QueueModel.ensureIndex finished_at: 1
      @QueueModel.ensureIndex 'options.timezone': 1
      @QueueModel.ensureIndex unique_id: 1,
        unique: true
        dropDups: true
    ]

    @on 'sent', ({address, options: {language, timezone}}) ->
      @logger?.log "[Queue] #{address} (#{language} @ #{timezone})"

    @queue = async.queue =>
      @worker arguments...
    , @options.threads

    @queue.on 'empty', =>
      @onQueueEmpty()

    @onQueueEmpty()

  pause: ->
    @paused = true

  resume: ->
    @paused = false
    @onQueueEmpty()

  pushMail: ({template, unique_id, address, locals, options}, callback) ->
    @QueueModel.create
      address: address
      created_at: new Date()
      unique_id: unique_id
      template: template
      locals: locals
      options: options
    .then (mail) =>
      if @queue.length() == 0
        @fetchMail()
    .nodeify callback

  onQueueEmpty: ->
    if @paused
      return

    async.until =>
      return @queue.length() > 0
    , =>
      @fetchMail().then (mail) =>
        if mail
          @queue.push mail
          return
        else
          return Q.delay @delay

  fetchMail: ->
    @ready.then =>
      @getAvailableTimezones (available_timezones) =>
        @QueueModel.findOneAndUpdate
          finished_at:
            $exists: false
          $and: [
            $or: [
              timezone:
                $exists: false
            ,
              timezone:
                $type: 10
            ,
              timezone:
                $in: available_timezones
            ]
          ,
            $or: [
              started_at:
                $exists: false
            ,
              started_at:
                $lt: new Date Date.now() - @options.timeout
            ]
          ]
        ,
          $set:
            started_at: new Date()
        ,
          sort:
            created_at: 1

  worker: (mail) ->
    {template, address, locals, options} = mail

    @mailer.sendMail(template, address, locals, options).then (res) =>
      @emit 'sent', mail, res

      mail.update
        $set:
          response: res
          finished_at: new Date()

  getAvailableTimezones: ->
    @QueueModel.aggregate([
      $group:
        _id: '$options.timezone'
    ]).then (rows) =>
      return _.pluck(rows, '_id').filter (timezone) =>
        if timezone
          {local_time_start, local_time_end} = @options
          return local_time_start <= moment().tz(timezone).hour() < local_time_end
        else
          return true
