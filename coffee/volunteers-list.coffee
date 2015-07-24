$ ->
  $('.btn-approve').on 'click', ->
    $this  = $(@)
    workId = $this.data('work-id')
    $.ajax "/volunteers/#{workId}/status",
      type: 'PUT'
      data: { status: 'approved' }
      success: (data, textStatus, jqXHR) ->
        $this.closest('.list-group-item').remove()
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $('.btn-cancel').on 'click', ->
    $this  = $(@)
    workId = $this.data('work-id')
    $.ajax "/volunteers/#{workId}/status",
      type: 'PUT'
      data: { status: 'canceled' }
      success: (data, textStatus, jqXHR) ->
        $this.closest('.list-group-item').remove()
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
