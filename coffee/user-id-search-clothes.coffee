$ ->
  $('span.category').each (i, el) ->
    $(el).html OpenCloset.category[ $(el).data('category') ].str

  $('span.color').each (i, el) ->
    $(el).html OpenCloset.color[ $(el).data('color') ]
