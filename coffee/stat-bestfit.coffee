$ ->
  $('span.category').each (i, el) ->
    $(el).html OpenCloset.category[ $(el).data('category') ].str
