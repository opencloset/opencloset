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

  updateSummary = (ymd, success_cb) ->
    #
    # 최상단의 요약 정보 갱신
    #
    $.ajax "/api/gui/timetable/#{ymd}.json",
      type: 'GET'
      success: (data, textStatus, jqXHR) ->
        $('.count-all-total').html(data.all.total)
        $('.count-visited-total').html(data.visited.total)
        $('.count-notvisited-total').html(data.notvisited.total)
        $('.count-bestfit-total').html(data.bestfit.total)

        $('.count-all-male').html(data.all.male)
        $('.count-visited-male').html(data.visited.male)
        $('.count-notvisited-male').html(data.notvisited.male)
        $('.count-bestfit-male').html(data.bestfit.male)

        $('.count-all-female').html(data.all.female)
        $('.count-visited-female').html(data.visited.female)
        $('.count-notvisited-female').html(data.notvisited.female)
        $('.count-bestfit-female').html(data.bestfit.female)

        success_cb() if success_cb

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
        updateSummary(ymd, success_cb)

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
      ...
      39: 탈의20
       6: 수선
      18: 포장

    ###
    if parseInt(status_id) in [ 14, 12, 13, 16, 17, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 6, 18 ]
      $(el).editable 'enable'
      $(el).closest('.widget-body').removeClass('prohibit-change-status')
    else
      $(el).editable 'disable'
      $(el).closest('.widget-body').addClass('prohibit-change-status')

    ###

      처리중인 사람들을 구분하기 위해 색상을 다르게 표시합니다.

      13: 방문
      16: 치수측정
      17: 의류준비
      20: 탈의01
      ...
      39: 탈의20
       6: 수선
      18: 포장
      19: 결제대기

    ###
    if parseInt(status_id) in [ 13, 16, 17, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 6, 18, 19 ]
      $(el).closest('.widget-body').addClass('processing-status')
    else
      $(el).closest('.widget-body').removeClass('processing-status')

    ###

      방문하지 않은 사람은 조금 더 명확하게 표시합니다.

      12: 방문안함

    ###
    if parseInt(status_id) in [ 12 ]
      $(el).closest('.widget-body').addClass('notvisit-status')
    else
      $(el).closest('.widget-body').removeClass('notvisit-status')

  #
  # 시간표내 각각의 주문서 상태 변경
  #
  available_status = [
    '방문예약',
    '방문안함',
    '대여안함',
    '사이즈없음',
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
    '탈의12',
    '탈의13',
    '탈의14',
    '탈의15',
    '수선',
    '포장',
  ]
  defaultSource = ( { value: OpenCloset.status[i]['id'], text: i } for i in available_status )

  $('.editable.order-status').each (i, el) ->
    $(el).on 'click', (e) ->
      ## url 이 변경되지 않으면 한번만 요청한다.
      ## https://github.com/vitalets/x-editable/issues/75
      $(el).editable('option', 'source', "#{CONFIG.monitor_uri}/api/status?available" + '&' + Math.random())

    $(el).editable(
      mode:        'inline'
      showbuttons: 'true'
      emptytext:   '상태없음'
      type:        'select'
      source:      defaultSource
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

  $('.editable.order-status').each (i, el) -> updateStatus(el)
  $('.editable.order-status').on 'save', (e, params) -> updateStatus(this, params.newValue)

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
          when 31 then status_id = 18 # 탈의12   -> 포장
          when 32 then status_id = 18 # 탈의13   -> 포장
          when 33 then status_id = 18 # 탈의14   -> 포장
          when 34 then status_id = 18 # 탈의15   -> 포장
          when  6 then status_id = 18 # 수선     -> 포장
          else return
        success_cb = () ->
          $(storage).find('.editable.order-status').editable( 'setValue', status_id, true )
          $(storage).find('.editable.order-status').each (i, el) -> updateStatus(el)
        updateOrder order_id, ymd, status_id, alert_target, success_cb
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('danger', "현재 주문서 상태를 확인할 수 없습니다: #{jqXHR.responseJSON.error.str}", "##{alert_target}")

  #
  # 어울림
  #
  $('.editable.order-bestfit').editable
    source: -> { value: k, text: v } for k, v of { 0: '보통', 1: 'Best-Fit' }
    success: (response, newValue) ->
      storage = $('.editable.order-bestfit').closest('.people-box')
      ymd     = storage.data('ymd')
      updateSummary storage.data('ymd')

  statusMap = {}
  ( statusMap[v.id] = k ) for k, v of OpenCloset.status
  url  = "#{CONFIG.monitor_uri}/socket".replace 'http', 'ws'
  sock = new ReconnectingWebSocket url, null, { debug: false }
  sock.onopen = (e) ->
    sock.send '/subscribe order'
  sock.onmessage = (e) ->
    data     = JSON.parse(e.data)
    order_id = data.order.id
    bestfit  = data.order.bestfit
    $box     = $(".people-box[data-order-id='#{order_id}']")
    if $box.find('.order-status').data('value') isnt data.to
      $editable = $box.find('.editable.order-status')
      $editable.editable('setValue', data.to, true)
      updateStatus($editable)
    if $box.find('.order-bestfit').data('value') isnt bestfit
      $editable = $box.find('.editable.order-bestfit')
      $editable.editable('setValue', bestfit, true)
  sock.onerror = (e) ->
    location.reload()

  #
  # 같은 이름 찾기
  #
  nameOrderMap = {}
  $('.people-box').each ->
    order_id = $(@).data('order-id')
    name = $(@).find('.widget-header > h4 > a').text().trim().split(' ')[0]
    unless nameOrderMap[name]
      nameOrderMap[name] = order_id
    else
      exists = nameOrderMap[name]
      $(".people-box[data-order-id=#{exists}]").addClass('name-duplicated')
      $(@).addClass('name-duplicated')
