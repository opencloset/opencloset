$ ->
  $("#query").datepicker(
    todayHighlight: true
    autoclose:      true
  ).on( 'changeDate', (e) ->
    ymd = $('#query').prop('value')
    window.location = "/timetable/#{ymd}"
  )

  $('.pre_category').each (i, el) ->
    keys_str   = $(el).data('category') || ''
    values_str = ( OpenCloset.category[i].str for i in keys_str.split(',') ).join(',')
    $(el).html( values_str )

  $('.pre_color').each (i, el) ->
    keys_str   = $(el).data('color') || ''
    values_str = ( OpenCloset.color[i] for i in keys_str.split(',') ).join(',')
    $(el).html( values_str )

  $('#btn-slot-open').click (e) ->
    ymd = $('#btn-slot-open').data('date-ymd')
    window.location = "/timetable/#{ymd}/open"

  updateTimeTablePerson = (btn) ->
    ub_id     = $(btn).data('id')
    ub_status = $(btn).data('status')
    url       = $("#timetable-data").data('url') + "/#{ ub_id }"
    $(btn)
      .removeClass('btn-primary')
      .removeClass('btn-danger')
      .removeClass('btn-warning')
      .removeClass('btn-success')
      .removeClass('btn-info')
      .removeClass('btn-inverse')
    if ub_status is 'visiting'
      $(btn).addClass('btn-info')

  $('.btn.timetable-person').each (i, el) ->
    updateTimeTablePerson(el)

  $('.btn.timetable-person').click (e) ->
    btn       = this
    ub_id     = $(btn).data('id')
    ub_status = $(btn).data('status')
    url       = $("#timetable-data").data('url') + "/#{ ub_id }.json"

    ub_status_new = ''
    if ub_status is 'visiting'
      ub_status_new = ''
    else
      ub_status_new = 'visiting'

    $(btn).data( 'status', ub_status_new )
    $.ajax url,
      type: 'PUT'
      data:
        id:     ub_id
        status: ub_status_new
        success: (data, textStatus, jqXHR) ->
          updateTimeTablePerson(btn)

  updateOrder = ( order_id, ymd, status_id, alert_target ) ->
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

        #
        # 드롭다운의 주문서 상태 레이블을 갱신
        #
        status_label = ''
        for k, v of OpenCloset.status
          continue unless v.id == status_id
          status_label = k
          break
        $("#label-order-status-#{ order_id }").html(status_label)
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('danger', "주문서 상태 변경에 실패했습니다: #{jqXHR.responseJSON.error.str}", "##{alert_target}")

  #
  # 시간표내 각각의 주문서 드롭다운 상태 변경
  #
  # 클릭 후 .open 클래스를 제거해  드롭다운을 안보이게 하면 좋겠지만
  # 실제로 동작하지 않기 때문에 일단은 그대로 둡니다.
  #
  # http://stackoverflow.com/questions/10941540/how-to-hide-twitter-bootstrap-dropdown
  #
  $('.dropdown-people a.order-status').click (e) ->
    storage      = $(this).closest('.dropdown-people')
    order_id     = storage.data('order-id')
    alert_target = storage.data('target')
    ymd          = storage.data('ymd')
    status_id    = $(this).data('status-id')

    updateOrder order_id, ymd, status_id, alert_target

  #
  # 각각의 주문서에서 다음 상태로 상태 변경
  #
  # 14 => 방문예약
  # 12 => 미방문
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
  #
  #  6 => 수선
  # 18 => 포장
  # 19 => 결제대기
  #
  $('.dropdown-people a.order-next-status').click (e) ->
    storage      = $(this).closest('.dropdown-people')
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
          when 18 then status_id = 19 # 포장     -> 결제대기
          when  6 then status_id = 18 # 수선     -> 포장
          else return
        updateOrder order_id, ymd, status_id, alert_target
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('danger', "현재 주문서 상태를 확인할 수 없습니다: #{jqXHR.responseJSON.error.str}", "##{alert_target}")
