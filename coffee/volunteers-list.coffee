$ ->
  volunteer_uri = CONFIG.volunteer_uri
  $('.btn-approve').on 'click', ->
    $this  = $(@)
    workId = $this.data('work-id')
    $.ajax "#{volunteer_uri}/works/#{workId}/status",
      type: 'PUT'
      crossDomain: true
      data: { status: 'approved' }
      success: (data, textStatus, jqXHR) ->
        $this.closest('.list-group-item').remove()
        location.reload true
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $('.btn-cancel').on 'click', ->
    $this  = $(@)
    workId = $this.data('work-id')
    $.ajax "#{volunteer_uri}/works/#{workId}/status",
      type: 'PUT'
      crossDomain: true
      data: { status: 'canceled' }
      success: (data, textStatus, jqXHR) ->
        $this.closest('.list-group-item').remove()
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $('.btn-done').on 'click', ->
    $this  = $(@)
    workId = $this.data('work-id')
    $.ajax "#{volunteer_uri}/works/#{workId}/status",
      type: 'PUT'
      crossDomain: true
      data: { status: 'done' }
      success: (data, textStatus, jqXHR) ->
        $this.closest('.list-group-item').remove()
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
