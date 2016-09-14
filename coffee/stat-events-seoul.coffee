$ ->
  $("#query").datepicker(
    todayHighlight: true
    autoclose:      true
  ).on( 'changeDate', (e) ->
    ymd = $('#query').prop('value')
    location.href = "#{location.pathname}?ymd=#{ymd}"
  )

$('.daily-stat .btn').click (e) ->
  e.preventDefault()

  $this = $(@)
  collapse = $this.closest('.collapse-group').find('.collapse')
  collapse.collapse('toggle')
