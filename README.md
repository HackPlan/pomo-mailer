# Pomo Mailer

* Render multi-language mail with jade template.
* Mail queue based on MongoDB, send mail by local timezone.
* Manage cyclical task, resume from original progress when terminated.
* Built-in some useful templates.
* Mail agent using HTTP API.

## Mailer

```coffee
{Mailer} = require 'pomo-mailer'

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

## Queue

## Agent

## Task
