fs = require 'fs'

{Mailer} = pomoMailer

renderedHtml = (name) ->
  return fs.readFileSync("#{__dirname}/rendered/#{name}.html").toString()

describe 'templates', ->
  mailer = new Mailer
    server: {}

  it 'action', ->
    mailer.render 'action',
      title: 'Please confirm your email address by clicking the link below.'
      detail: 'We may need to send you critical information about our service and it is important that we have an accurate email address.'
      link: 'http://www.mailgun.com'
      action: 'Confirm email address'
      copyright: '— The Mailgunners'

      unsubscribe:
        before: 'Follow'
        link: 'http://twitter.com/mail_gun'
        action: '@Mail_Gun'
        after: 'on Twitter.'
    .then (mail) ->
      mail.html.should.be.equal renderedHtml 'action'

  it 'alert', ->
    mailer.render 'alert',
      alert: "Warning: You're approaching your limit. Please upgrade."
      title: 'You have 1 free report remaining.'
      detail: "Add your credit card now to upgrade your account to a premium plan to ensure you don't miss out on any reports."
      link: 'http://www.mailgun.com'
      action: 'Upgrade my account'
      copyright: 'Thanks for choosing Acme Inc.'

      unsubscribe:
        before: ''
        link: 'http://twitter.com/mail_gun'
        action: 'Unsubscribe'
        after: 'from these alerts.'
    .then (mail) ->
      mail.html.should.be.equal renderedHtml 'alert'

  it 'billing', ->
    mailer.render 'billing',
      title: '$33.98 Paid'
      detail: 'Thanks for using Acme Inc.'
      address: [
        'Lee Munroe'
        'Invoice #12345'
        'June 01 2014'
      ]

      products: [
        name: 'Service 1'
        price: '$ 19.99'
      ,
        name: 'Service 2'
        price: '$ 9.99'
      ,
        name: 'Service 3'
        price: '$ 4.00'
      ]

      total:
        name: 'Total'
        price: '$ 33.98'

      link: 'http://www.mailgun.com'
      action: 'View in browser'
      copyright: 'Acme Inc. 123 Van Ness, San Francisco 94102'

      unsubscribe:
        before: 'Questions? Email'
        link: 'mailto:'
        action: 'support@acme.inc'
        after: ''
    .then (mail) ->
      mail.html.should.be.equal renderedHtml 'billing'