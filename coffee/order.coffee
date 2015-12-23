$ ->
  sock = null

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
    $(el).addClass OpenCloset.status[status]?.css if status

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
      beforeSend: ->
        sock.close() if sock
      success: (data) ->
        location.href = $this.closest('a').prop('href')
      error: (jqXHR, textStatus) ->
        OpenCloset.alert('danger', "주문서 상태 변경에 실패했습니다: #{jqXHR.responseJSON.error.str}")

  ## 포장완료 상태에 대해서 실시간으로 갱신 Github #647
  boxed_id = OpenCloset.status['포장완료'].id
  if /44/.test(location.search or '')
    url  = "#{CONFIG.monitor_uri}/socket".replace 'http', 'ws'
    sock = new ReconnectingWebSocket url, null, { debug: false, reconnectInterval: 3000 }
    sock.onopen = (e) ->
      sock.send '/subscribe order'
    sock.onmessage = (e) ->
      data     = JSON.parse(e.data)
      order_id = data.order.id
      if parseInt(data.to) is boxed_id or parseInt(data.from) is boxed_id
        location.reload()
    sock.onerror = (e) ->
      location.reload()

  ## 미납금 완납, 불납
  $('a.late-fee-done[rel*=facebox]').on 'click', (e) ->
    e.preventDefault()
    $(@).closest('tr').toggleClass('active')
    $.facebox({ div: $(@).attr('href') })
  $(document).bind 'reveal.facebox', ->
    $tr      = $('table tr.active')
    late_fee = $tr.find('td:nth-child(2) a:first').text()
    username = $tr.find('td:nth-child(5) a').text()
    $('#facebox span.username').text("#{username}님")
    $('#facebox code.late-fee').text(late_fee)
  $(document).bind 'afterClose.facebox', ->
    $('table tr').removeClass('active')

  $('body').on 'click', '#facebox .late-fee-method', (e) ->
    e.preventDefault()
    order_id = $('table tr.active td:first a').text()
    method   = $(@).text()
    $.ajax "/api/order/#{order_id}.json",
      type: 'PUT'
      data:
        id: order_id
        compensation_pay_with: '완납'
        late_fee_pay_with: method
      success: (data) ->
        $('table tr.active').remove()
        $.facebox.close()
        OpenCloset.alert('success', "완납 처리되었습니다")
      error: (jqXHR, textStatus) ->
        OpenCloset.alert('danger', "오류가 발생했습니다: #{jqXHR.responseJSON.error.str}")

  $('.late-fee-deny').on 'click', (e) ->
    e.preventDefault()
    return unless confirm '불납 으로 변경하시겠습니까?'
    $tr      = $(@).closest('tr')
    order_id = $tr.find('td:first a').text()
    $.ajax "/api/order/#{order_id}.json",
      type: 'PUT'
      data:
        id: order_id
        compensation_pay_with: '불납'
        late_fee_pay_with: 'NULL'
      success: (data) ->
        $tr.remove()
        OpenCloset.alert('success', "불납 처리되었습니다")
      error: (jqXHR, textStatus) ->
        OpenCloset.alert('danger', "오류가 발생했습니다: #{jqXHR.responseJSON.error.str}")
  ## 미납금 완납, 불납 end
