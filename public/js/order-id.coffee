$ ->
  $('span.order-status.label').each (i, el) ->
    $(el).addClass( OpenCloset.getStatusCss $(el).data('order-status') )
    $(el).html('연체중') if $(el).data('order-late-fee') > 0
