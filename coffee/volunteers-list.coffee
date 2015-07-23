Date.prototype.ymd = ->
  yyyy = @getFullYear().toString()
  mm = (@getMonth() + 1).toString()
  dd = @getDate().toString()
  return yyyy + '-' + (if mm[1] then mm else "0" + mm[0]) + '-' + (if dd[1] then dd else "0"+dd[0])

$ ->
  $('.datepicker').datepicker
    language: 'kr'
    todayHighlight: true
    format: 'yyyy-mm-dd'
  .on 'changeDate', (e) ->
    ymd = e.date.ymd()
    location.href = "/volunteers?date=#{ymd}"
