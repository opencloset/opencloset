$ ->
  #
  # 사용자 더하기
  #
  $('#query').focus()
  $('#query').keypress (e) -> $('#btn-search').click() if e.keyCode is 13
  $('#btn-add').click (e) ->
    console.log 'btn-add clicked'
  $('#btn-search').click (e) ->
    url = "#{window.location.pathname}?#{$.param( { q: $('#query').val() } )}"
    window.location.assign url
