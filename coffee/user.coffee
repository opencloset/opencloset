$ ->
  #
  # 입력창에 포커스
  #
  $('#query').focus()

  #
  # 입력창 키코드 맵핑
  #
  $('#query').keyup (e) ->
    switch e.keyCode
      when 13 then $('#btn-search').click()
      when 27 then $('#query').val('')

  #
  # 검색 버튼 클릭
  #
  $('#btn-search').click (e) ->
    url = "#{window.location.pathname}?#{$.param( { q: $('#query').val() } )}"
    window.location.assign url
  #
  # 지우기 버튼 클릭
  #
  $('#btn-clear').click (e) ->
    $('#query').val('')
    $('#query').focus()
  #
  # 추가 버튼 클릭
  #
  $('#btn-add').click (e) ->
    name = $('#query').val()
    $.ajax '/api/user.json',
      type: 'POST'
      data: { name: name }
      success: (data, textStatus, jqXHR) ->
        userID = data.id
        url    = "/user/#{userID}"
        window.location.assign url
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('warning', "사용자를 추가하지 못했습니다. - #{jqXHR.responseJSON.error.str}")
      complete: (jqXHR, textStatus) ->
