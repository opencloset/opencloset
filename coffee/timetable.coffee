$ ->
  $("#query").datepicker(
    todayHighlight: true
    autoclose:      true
  ).on( 'changeDate', (e) ->
    ymd = $('#query').prop('value')
    window.location = "/timetable/#{ymd}"
  )

  $('.pre_category').each (i, el) ->
    keys_str = $(el).data('category') || ''

    values = []
    for i in keys_str.split(',')
      item = OpenCloset.category[i]
      continue unless item
      str = item.str.replace /^\s+|\s+$/, ""
      continue if str is ''
      values.push str
    values_str = values.join(',')

    $(el).html( values_str )

  $('.pre_color').each (i, el) ->
    keys_str = $(el).data('color') || ''

    values = []
    for i in keys_str.split(',')
      item = OpenCloset.color[i]
      continue unless item
      str = item.replace /^\s+|\s+$/, ""
      continue if str is ''
      values.push str
    values_str = values.join(',')

    $(el).html( values_str )

  updateOrder = ( order_id, ymd, status_id, alert_target, success_cb ) ->
    #
    # 주문서의 상태 갱신
    #
    $.ajax "/api/order/#{order_id}.json",
      type: 'PUT'
      data:
        id:        order_id
        status_id: status_id
      success: (data, textStatus, jqXHR) ->
        #
        # 상태 변경에 성공
        #

        #
        # 최상단의 요약 정보 갱신
        #
        $.ajax "/api/gui/timetable/#{ymd}.json",
          type: 'GET'
          success: (data, textStatus, jqXHR) ->
            $('#count-all').html(data.all)
            $('#count-visited').html(data.visited)
            $('#count-notvisited').html(data.notvisited)
            success_cb() if success_cb
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('danger', "주문서 상태 변경에 실패했습니다: #{jqXHR.responseJSON.error.str}", "##{alert_target}")

  updateStatus = (el, status_id) ->
    status_id = $(el).editable( 'getValue', true ) unless status_id
    ###

      다음의 경우에 한해 상태 변경이 가능하도록 허용합니다.

      14: 방문예약
      12: 방문안함
      13: 방문
      16: 치수측정
      17: 의류준비
      20: 탈의01
      21: 탈의02
      22: 탈의03
      23: 탈의04
      24: 탈의05
      25: 탈의06
      26: 탈의07
      27: 탈의08
      28: 탈의09
      29: 탈의10
      30: 탈의11
       6: 수선
      18: 포장

    ###
    if parseInt(status_id) in [ 14, 12, 13, 16, 17, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 6, 18 ]
      $(el).editable 'enable'
      $(el).closest('.widget-body').removeClass('prohibit-change-status')
    else
      $(el).editable 'disable'
      $(el).closest('.widget-body').addClass('prohibit-change-status')

  #
  # 시간표내 각각의 주문서 상태 변경
  #
  $('.editable').each (i, el) ->
    available_status = [
      '방문예약',
      '방문안함',
      '대여안함',
      '방문',
      '치수측정',
      '의류준비',
      '탈의01',
      '탈의02',
      '탈의03',
      '탈의04',
      '탈의05',
      '탈의06',
      '탈의07',
      '탈의08',
      '탈의09',
      '탈의10',
      '탈의11',
      '수선',
      '포장',
    ]
    $(el).editable(
      mode:        'inline'
      showbuttons: 'true'
      emptytext:   '상태없음'
      type:        'select'
      source:      ( { value: OpenCloset.status[i]['id'], text: i } for i in available_status )
      url: (params) ->
        storage      = $(el).closest('.people-box')
        order_id     = storage.data('order-id')
        alert_target = storage.data('target')
        ymd          = storage.data('ymd')
        status_id    = params.value
        updateOrder order_id, ymd, status_id, alert_target
      display: (value, sourceData) ->
        unless value
          $(this).empty()
          return
        mapped = {}
        ( mapped[v.id] = k ) for k, v of OpenCloset.status
        $(this).html mapped[value]
    )

  $('.editable').each (i, el) -> updateStatus(el)
  $('.editable').on 'save', (e, params) -> updateStatus(this, params.newValue)

  #
  # 각각의 주문서에서 다음 상태로 상태 변경
  #
  # 14 => 방문예약
  # 12 => 방문안함
  # 13 => 방문
  # 16 => 치수측정
  # 17 => 의류준비
  #
  # 20 => 탈의01
  # 21 => 탈의02
  # 22 => 탈의03
  # 23 => 탈의04
  # 24 => 탈의05
  # 25 => 탈의06
  # 26 => 탈의07
  # 27 => 탈의08
  # 28 => 탈의09
  # 29 => 탈의10
  # 30 => 탈의11
  #
  #  6 => 수선
  # 18 => 포장
  # 19 => 결제대기
  #
  $('.people-box a.order-next-status').click (e) ->
    storage      = $(this).closest('.people-box')
    order_id     = storage.data('order-id')
    alert_target = storage.data('target')
    ymd          = storage.data('ymd')

    #
    # 주문서의 현재 상태
    #
    $.ajax "/api/order/#{order_id}.json",
      type:    'GET'
      success: (data, textStatus, jqXHR) ->
        switch parseInt(data.status_id)
          when 14 then status_id = 13 # 방문예약 -> 방문
          when 13 then status_id = 16 # 방문     -> 치수측정
          when 16 then status_id = 17 # 치수측정 -> 의류준비
          when 20 then status_id = 18 # 탈의01   -> 포장
          when 21 then status_id = 18 # 탈의02   -> 포장
          when 22 then status_id = 18 # 탈의03   -> 포장
          when 23 then status_id = 18 # 탈의04   -> 포장
          when 24 then status_id = 18 # 탈의05   -> 포장
          when 25 then status_id = 18 # 탈의06   -> 포장
          when 26 then status_id = 18 # 탈의07   -> 포장
          when 27 then status_id = 18 # 탈의08   -> 포장
          when 28 then status_id = 18 # 탈의09   -> 포장
          when 29 then status_id = 18 # 탈의10   -> 포장
          when 30 then status_id = 18 # 탈의11   -> 포장
          when  6 then status_id = 18 # 수선     -> 포장
          else return
        success_cb = () ->
          $(storage).find('.editable').editable( 'setValue', status_id, true )
          $(storage).find('.editable').each (i, el) -> updateStatus(el)
        updateOrder order_id, ymd, status_id, alert_target, success_cb
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('danger', "현재 주문서 상태를 확인할 수 없습니다: #{jqXHR.responseJSON.error.str}", "##{alert_target}")

  statusMap = {}
  ( statusMap[v.id] = k ) for k, v of OpenCloset.status
  url  = "#{CONFIG.monitor_uri}/socket".replace 'http', 'ws'
  sock = new ReconnectingWebSocket url, null, { debug: false }
  sock.onopen = (e) ->
    sock.send '/subscribe order'
  sock.onmessage = (e) ->
    data     = JSON.parse(e.data)
    order_id = data.order.id
    $box     = $(".people-box[data-order-id='#{order_id}']")
    if $box.find('.order-status').data('value') isnt data.to
      $editable = $box.find('.editable.order-status')
      $editable.editable('setValue', data.to, true)
      updateStatus($editable)
  sock.onerror = (e) ->
    location.reload()
