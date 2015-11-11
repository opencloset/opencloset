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

  $('.status-update').on 'click', (e) ->
    e.preventDefault()
    $this = $(@)
    order_id  = $this.data('order-id')
    status_to = $this.data('status-to')
    $.ajax "/api/order/#{order_id}.json",
      type: 'PUT'
      data: { id: order_id, status_id: status_to }
      success: (data) ->
        location.href = $this.closest('a').prop('href')
      error: (jqXHR, textStatus) ->
        OpenCloset.alert('danger', "주문서 상태 변경에 실패했습니다: #{jqXHR.responseJSON.error.str}")
