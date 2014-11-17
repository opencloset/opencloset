$ ->
  $('span.order-status.label').each (i, el) ->
    $(el).addClass OpenCloset.status[ $(el).data('status') ].css
  $('span.category').each (i, el) ->
    $(el).html OpenCloset.category[ $(el).data('category') ].str
