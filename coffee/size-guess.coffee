$ ->
  $('input[name=height]').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('input[name=height]').val('')
    $('input[name=weight]').val('')
    $('select[name=gender]').val('')
    $('input[name=height]').focus()
  $('#btn-size-guess').click (e) ->
    $('#form-size-guess').trigger('submit')
