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

  $('.btn-1365:not(.disabled)').on 'click', ->
    $this  = $(@)
    $this.addClass('disabled')
    workId = $this.data('work-id')
    hasSuccess = $this.hasClass('btn-success')
    $this.removeClass('btn-success btn-danger')
    $.ajax "#{volunteer_uri}/works/#{workId}/1365",
      type: 'PUT'
      crossDomain: true
      data: { 1365: if hasSuccess then '0' else '1' }
      success: (data, textStatus, jqXHR) ->
        $this.addClass(if hasSuccess then 'btn-danger' else 'btn-success')
        $this.find('span').text(if hasSuccess then '승인대기중' else '승인됨')
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
