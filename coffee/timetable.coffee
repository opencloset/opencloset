$ ->
  $("#query").datepicker(
    todayHighlight: true
    autoclose:      true
  ).on( 'changeDate', (e) ->
    ymd = $('#query').prop('value')
    window.location = "/timetable/#{ymd}"
  )

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
    status_id    = $(this).data('status-id')

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
        # 상태 변경에 성공했으므로 드롭다운의 주문서 상태 레이블을 갱신
        #
        status_label = ''
        for k, v of OpenCloset.status
          continue unless v.id == status_id
          status_label = k
          break
        $("#label-order-status-#{ order_id }").html(status_label)
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('danger', "주문서 상태 변경에 실패했습니다: #{jqXHR.responseJSON.error.str}", "##{alert_target}")
