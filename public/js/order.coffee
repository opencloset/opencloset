$ ->
  $('span.order-status.label').each (i, el) ->
    status = $(el).data('order-status')
    $(el).addClass OpenCloset.status[status].css if status
