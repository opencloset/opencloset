$ ->
  $('.order-status').each (i, el) ->
    $(el).addClass( OpenCloset.getStatusCss $(el).data('status') )
    $(el).find('.order-status-str').html('연체중') if $(el).data('late-fee') > 0
