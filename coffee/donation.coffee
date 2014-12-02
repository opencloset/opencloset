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

  $('.donation-clothes span').dblclick (e) ->
    e.preventDefault()
    $this = $(@)
    code = $this.data('clothes-code')
    $.ajax "/api/clothes/#{code}.json",
      type: 'PUT'
      data: { donation_id: null }
      success: (data, textStatus, jqXHR) ->
        $this.appendTo('#clothes-bucket ul')
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
