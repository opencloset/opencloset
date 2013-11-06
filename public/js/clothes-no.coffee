$ ->
  $('#btn-edit').click (e) ->
    e.preventDefault()
    $(@).hide()
    $('#input-edit').show()
    $('#edit input:first').focus().select()

  $('#btn-cancel').on 'click', (e) ->
    e.preventDefault()
    $('#input-edit').hide()
    $('#btn-edit').show()

  $('#btn-submit:not(.disabled)').on 'click', (e) ->
    $this = $(@)
    $this.addClass('disabled')
    e.preventDefault()
    $.ajax location.href,
      type: 'PUT'
      data: $('#edit').serialize()
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
