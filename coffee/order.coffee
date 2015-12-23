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


  ## 포장완료 상태에 대해서 실시간으로 갱신 Github #647
  boxed_id = OpenCloset.status['포장완료'].id
  if /44/.test(location.search or '')
    url  = "#{CONFIG.monitor_uri}/socket".replace 'http', 'ws'
    sock = new ReconnectingWebSocket url, null, { debug: false }
    sock.onopen = (e) ->
      sock.send '/subscribe order'
    sock.onmessage = (e) ->
      data     = JSON.parse(e.data)
      order_id = data.order.id
      if parseInt(data.from) is boxed_id or parseInt(data.to) is boxed_id
        location.reload()
    sock.onerror = (e) ->
      location.reload()
