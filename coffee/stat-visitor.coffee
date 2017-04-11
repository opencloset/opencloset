$ ->
  $("#query").datepicker(
    todayHighlight: true
    autoclose:      true
  ).on( 'changeDate', (e) ->
    ymd = $('#query').prop('value')
    path = location.pathname.split('/')
    path.pop()
    path.push(ymd)
    location.href = path.join('/')
  )
