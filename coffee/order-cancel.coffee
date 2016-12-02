$ ->
  $('#btn-cancel').click ->
    $this = $(@)
    return if $this.hasClass('disabled')
    $this.addClass('disabled')
    $.ajax $this.data('url'),
      type: 'DELETE'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $('p').remove()
        $('<p>취소되었습니다.</p>').insertAfter('h3')
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
