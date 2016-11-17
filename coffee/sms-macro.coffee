$ ->
  $('#form-macro').submit (e) ->
    e.preventDefault()
    $form = $(@)
    $.ajax $(@).prop('action'),
      type: 'PUT'
      data: $form.serialize()
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        location.reload()

  $('#btn-delete-macro').click (e) ->
    e.preventDefault()
    return unless confirm "삭제하시겠습니까?"
    $form   = $(@)
    listUrl = $(@).data('list-url')
    $.ajax $(@).prop('action'),
      type: 'DELETE'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        location.href = listUrl
