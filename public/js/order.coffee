$ ->
  $('span.order-status.label').each (i, el) ->
    $(el).addClass OpenCloset.status[ $(el).data('order-status') ].css
