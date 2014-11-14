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
