$ ->
  volunteer_uri = CONFIG.volunteer_uri
  $('.btn-status:not(.disabled)').on 'click', ->
    $this  = $(@)
    workId = $this.data('work-id')
    status = $this.data('status')
    return unless confirm "상태를 변경하시겠습니까? -> #{status}"
    $this.addClass('disabled')
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

  ## 0: 승인대기, 1: 승인됨, 2: 필요없음
  ## 0 -> 1 -> 2 -> 0 -> 1 -> 2 -> 0 -> ...
  _1365StateMap = { 0: 1, 1: 2, 2: 0 }
  _1365ClassMap = { 0: 'btn-danger', 1: 'btn-success', 2: 'btn-default' }
  _1365TextMap = { 0: '승인대기중', 1: '승인됨', 2: '필요없음' }
  $('.btn-1365:not(.disabled)').on 'click', ->
    $this  = $(@)
    $this.addClass('disabled')
    workId = $this.data('work-id')
    _1365  = _1365StateMap[$this.data('1365')]
    $this.removeClass('btn-success btn-danger btn-default')
    $.ajax "#{volunteer_uri}/works/#{workId}/1365",
      type: 'PUT'
      crossDomain: true
      data: { 1365: _1365 }
      success: (data, textStatus, jqXHR) ->
        $this.addClass(_1365ClassMap[_1365])
        $this.find('span').text(_1365TextMap[_1365])
        $this.data('1365', _1365)
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
