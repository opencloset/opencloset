$ ->
  # TODO: prevent double click
  $('#donation .btn').click (e) ->
    e.preventDefault()
    $this = $(@)
    url = $this.closest('form').prop('action')
    message = $this.closest('form').find('textarea').val()
    return unless message
    $.ajax url,
      type: 'PUT'
      data: { message: message }
      success: (data, textStatus, jqXHR) ->
        OpenCloset.alert '기증 메세지가 수정되었습니다.'
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
