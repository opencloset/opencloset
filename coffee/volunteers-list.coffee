$ ->
  volunteer_uri = CONFIG.volunteer_uri
  $('.btn-status:not(.disabled)').on 'click', ->
    $this  = $(@)
    $this.addClass('disabled')
    workId = $this.data('work-id')
    status = $this.data('status')
    $.ajax "#{volunteer_uri}/works/#{workId}/status",
      type: 'PUT'
      crossDomain: true
      data: { status: status }
      success: (data, textStatus, jqXHR) ->
        $this.closest('.list-group-item').remove()
        location.reload true
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
