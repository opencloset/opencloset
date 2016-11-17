$ ->
  $("#query").datepicker(
    todayHighlight: true
    autoclose:      true
  ).on( 'changeDate', (e) ->
    ymd = $('#query').prop('value')
    window.location = "/booking/#{ymd}"
  )

  $('#btn-slot-open').click (e) ->
    ymd = $('#btn-slot-open').data('date-ymd')
    window.location = "/booking/#{ymd}/open"

  #
  # inline editable field
  #
  $('.editable').each (i, el) ->
    params =
      mode:        'inline'
      showbuttons: 'true'
      emptytext:   '비어있음'
      url: (params) ->
        url  = $("#booking-data").data('url') + "/#{params.pk}.json"
        data = {}
        data[params.name] = params.value
        $.ajax url,
          type: 'PUT'
          data: data

    params.type = 'text'
    $(el).editable params

  $('.order-cancel').click (e) ->
    e.preventDefault()

    return unless confirm "취소하시겠습니까?"

    $this = $(@)
    to   = $this.data('phone')
    name = $this.data('name')
    msg  = $this.attr('title')
    url  = $this.attr('href')

    OpenCloset.sendSMS to, msg

    $.ajax url,
      type: 'DELETE'
      success: (data, textStatus, jqXHR) ->
        $this.closest('span.dropdown').remove()
        OpenCloset.alert 'info', "#{name}님 예약이 취소 되었습니다"
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert 'warning', textStatus
      complete: (jqXHR, textStatus) ->
