$ ->
  #
  # 사용자 더하기
  #
  $('#query').focus()
  $('#query').keyup (e) ->
    switch e.keyCode
      when 13 then $('#btn-search').click()
      when 27 then $('#query').val('')
  $('#btn-add').click (e) ->
    console.log 'btn-add clicked'
  $('#btn-search').click (e) ->
    url = "#{window.location.pathname}?#{$.param( { q: $('#query').val() } )}"
    window.location.assign url
  $('#btn-clear').click (e) ->
    $('#query').val('')
    $('#query').focus()
