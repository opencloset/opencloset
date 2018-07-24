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

  #
  # dropdown menu click
  #
  $("#btn-booking-modal-ok").click (e) ->
    $("#modal-booking").modal("hide")
  $(".dropdown").on "click", (e) ->
    $(".change-booking").nextAll().remove()
    $dropdown_element  = $(this)
    gender             = $(this).data("gender")
    ymd                = $(this).data("ymd")
    url                = $(this).data("url")
    user_name          = $(this).data("user-name")
    current_booking_id = $(this).data("current-booking-id")
    $.ajax "/api/gui/booking-list.json",
      type: "GET"
      data:
        gender: gender
        ymd:    ymd
      success: (data, textStatus, jqXHR) ->
        additionalBooking = ""
        for booking in data
          continue unless booking.user_count < booking.slot # show only slot is enough
          continue unless moment() < moment(booking.date)   # show only before the booking time
          continue unless booking.id > 0                    # show only booking is valid
          continue if     booking.id == current_booking_id  # show only different booking
          additionalBooking += "<li><a href='#' class='dropdown-item update-booking' type='button' data-booking-id='#{booking.id}' data-booking-date='#{booking.date}'>#{booking.date}</button></li>"
        $(".change-booking").after(additionalBooking)
        $(".update-booking").on "click", (e) ->
          e.defaultPrevented
          booking_id   = $(this).data("booking-id")
          booking_date = $(this).data("booking-date")
          return unless booking_id
          $.ajax url,
            type: "PUT"
            data: { booking_id: booking_id }
            success: (data, textStatus, jqXHR) ->
              location.reload(true)
              $dropdown_element.remove()
              OpenCloset.alert "info", "#{user_name}님 #{booking_date}로 예약이 변경되었습니다."
              $("#modal-booking").on "show.bs.modal", (e) ->
                $("#modal-user-name").html(user_name)
                $("#modal-booking-date").html(booking_date)
              $("#modal-booking").on "hide.bs.modal", (e) ->
                $("#modal-user-name").html("")
                $("#modal-booking-date").html("")
                location.reload(true)
              $("#modal-booking").modal("show")
            error: (jqXHR, textStatus, errorThrown) ->
              OpenCloset.alert "warning", jqXHR.responseJSON.error.str
            complete: (jqXHR, textStatus) ->
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

  $('.order-cancel').click (e) ->
    e.preventDefault()

    return unless confirm "취소하시겠습니까?"

    $this = $(@)
    name = $this.data('name')
    url  = $this.attr('href')

    $.ajax url,
      type: 'DELETE'
      success: (data, textStatus, jqXHR) ->
        $this.closest('span.dropdown').remove()
        OpenCloset.alert 'info', "#{name}님 예약이 취소되었습니다"
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert 'warning', jqXHR.responseJSON.error.str
      complete: (jqXHR, textStatus) ->
