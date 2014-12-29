$ ->
  $("#booking-ymd").datepicker(
    todayHighlight: true
    autoclose:      true
  ).on( 'changeDate', (e) ->
    ymd = $('#booking-ymd').prop('value')
    url = "#{window.location.pathname}?#{$.param( { 'booking_ymd': $('#booking-ymd').val() } )}"
    window.location.assign url
  )

  $('span.order-status.label').each (i, el) ->
    status = $(el).data('order-status')
    $(el).addClass OpenCloset.status[status].css if status

  $('.clothes-category').each (i, el) ->
    $(el).html OpenCloset.category[el.text].str
