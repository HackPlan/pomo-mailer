{EventEmitter} = require 'events'
Mabolo = require 'mabolo'
moment = require 'moment-timezone'
async = require 'async-q'
_ = require 'lodash'
Q = require 'q'

###
  Public: Mail queue based on MongoDB.
###
module.exports = class Queue extends EventEmitter
  defaults:
    mailer: null
    mongodb: 'mongodb://localhost/pomo-mailer'

    timeout: 60 * 1000
    delay: 60 * 1000
    threads: 5

    local_time_start: 0
    local_time_end: 24

    logger: console

  ###
    Public: Constructor

    * `options` {Object}

      * `mailer` {Mailer}
      * `mongodb` (optional) {String} Uri of MongoDB.
      * `timeout` (optional) {Number} Default 60 * 1000.
      * `delay` (optional) {Number} Default 60 * 1000.
      * `threads` (optional) {Number} Default 5.
      * `local_time_start` (optional) {Number}
      * `local_time_end` (optional) {Number}
      * `logger` (optional) {Object} Default `console`

  ###
  constructor: (options) ->
    @options = _.defaults options, @defaults
    @mailer = @options.mailer

    @mabolo = new Mabolo @options.mongodb

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
        sparse: true
        dropDups: true
    ]

    @on 'sent', ({address, options: {language, timezone}}) ->
      @logger?.log "[Queue:sent] #{address} (#{language} @ #{timezone})"

    @on 'error', (err) ->
      @logger?.error '[Queue:error]', err

    @queue = async.queue =>
      @worker arguments...
    , @options.threads

    @queue.on 'empty', =>
      @onQueueEmpty()

    @onQueueEmpty()

  ###
    Public: Pause queue.
  ###
  pause: ->
    @paused = true

  ###
    Public: Resume queue.
  ###
  resume: ->
    @paused = false
    @onQueueEmpty()

  ###
    Public: Push mail into queue.

    * `mail` {Object}

      * `address` {String} To address.
      * `template` (optional) {String} Template name.
      * `unique_id` (optional) {String} Unique id.
      * `locals` (optional) {Object} Options pass to template.
      * `options` (optional) {Object} Overwrite {Mailer} options.

    * `callback` (optional) {Function}

    Return {Promise} resolve with queued mail.
  ###
  pushMail: ({template, unique_id, address, locals, options}, callback) ->
    @QueueModel.create
      address: address
      created_at: new Date()
      unique_id: unique_id
      template: template
      locals: locals
      options: options
    .tap (mail) =>
      if @queue.length() == 0
        @onQueueEmpty()
        return
    .nodeify callback

  # Private: Fill the workers.
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
          return Q.delay @options.delay

  # Private: Fetch mail form MongoDB atomically.
  fetchMail: ->
    @ready.then =>
      @getAvailableTimezones().then (available_timezones) =>
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

  # Private: Send mail use {Mailer}.
  worker: (mail) ->
    {template, address, locals, options} = mail

    @mailer.sendMail(template, address, locals, options).then (res) =>
      @emit 'sent', mail, res

      mail.update
        $set:
          response: res
          finished_at: new Date()

    .catch (err) ->
      @emit 'error', err, mail

  # Private: Get available timezones
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
