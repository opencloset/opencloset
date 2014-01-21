$ ->
  $('#query').focus()
  $('#btn-tag-add').click (e) ->
    $('#add-form').trigger('submit')

  $('#add-form').submit (e) ->
    e.preventDefault()
    query = $('#query').val()
    $('#query').val('').focus()
    return unless query

    console.log query
