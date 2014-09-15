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
