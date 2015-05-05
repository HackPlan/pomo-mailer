# Pomo Mailer

* Render multi-language mail with jade template.
* Mail queue based on MongoDB, send mail by local timezone.
* Manage cyclical task, resume from original progress when terminated.
* Built-in some useful templates.
* Mail agent using HTTP API.

```coffee
{Mailer, Queue, Agent, Task} = require 'pomo-mailer'
```

## Mailer

```coffee
mailer = new Mailer
  server:
    service: 'Postmark'
    auth:
      user: 'postmark-api-token'
      pass: 'postmark-api-token'

  from: 'Pomotodo <robot@pomotodo.com>'

mailer.sendMail 'action', 'jysperm@gmail.com',
  title: 'Please confirm your email address'
  link: 'https://pomotodo.com'
  action: 'Confirm'
.then console.log
.catch console.error
```

## Queue

```coffee
queue = new Queue
  mailer: mailer
  mongodb: 'mongodb://localhost/pomo-mailer-test'

queue.pushMail
  template: 'billing'
  address: 'jysperm@gmail.com'
  locals: generateBilling()
.then console.log
.catch console.error
```

## Agent

```coffee
agent = new Agent
  queue: queue
  users:
    jysperm: 'pass'

app = express()
app.use bodyParser.json()
app.use agent.express()
```

## Task

```coffee
task = new Task
  name: 'weekly'
  worker: worker
  groupBy: -> moment().format 'YYYY-W'
  nextGroup: -> moment().startOf('week').add(weeks: 1)

worker = (task) ->
  return Q.Promise (resolve, reject, notify) ->
    db.accounts.find
      _id:
        $gte: task.progress ? null
    .sort
      _id: true
    .then (accounts) ->
      async.each accounts, ({_id, email, generateWeekly}) ->
        notify _id
        mailer.sendMail 'weekly', email, generateWeekly()
```

## Built-in templates

* `action`
* `alert`
* `billing`

Some useful templates converted from [mailgun/transactional-email-templates](https://github.com/mailgun/transactional-email-templates).

Common fields:

* `title` {String}
* `detail` {String}
* `link` {String}
* `action` {String}
* `copyright` {String}

* `unsubscribe` {Object}

  * `before` {String}
  * `link` {String}
  * `action` {String}
  * `after` {String}

`alert` fields:

* `alert` {String}

`billing` fields:

* `address` {Array} of {String}
* `products` {Array}

  * `name` {String}
  * `price` {String}

* `total` {Object}

  * `name` {String}
  * `price` {String}
