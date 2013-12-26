$ ->
  $('span.order-status.label').each (i, el) ->
    $(el).addClass( OpenCloset.getStatusCss $(el).data('order-detail-status') )
    if $(el).data('order-detail-status') is '대여중' && $(el).data('order-late-fee') > 0
      $(el).html('연체중')
