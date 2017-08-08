$ ->
  $('.chosen-select').chosen()
  $('input[name="gender"]').on 'change', (e) ->
    gender = $(@).val()
    $('.gender-size').hide()
    $(".#{gender}-only").show()

  $('.btn-remove').click (e) ->
    $this = $(@)
    id = $this.data('id')
    $.ajax location.href,
      type: 'DELETE'
      dataType: 'json'
      data: { agent_id: id }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->

  $('#input-upload-csv').change (e) ->
    $(@).closest('form').submit()
