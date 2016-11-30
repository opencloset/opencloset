$ ->
  $('.booking-row').click (e) ->
    e.preventDefault()
    return if $(@).hasClass('disabled')
    $(@).addClass('disabled')

    datetime = $(@).text()
    unless confirm "#{datetime} 으로 예약시간을 변경하시겠습니까?"
      $(@).removeClass('disabled')
      return

    booking_id = $(@).data('booking-id')
    return unless booking_id

    $.ajax $(@).prop('href'),
      type: 'PUT'
      dataType: 'json'
      data: { booking_id: booking_id }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
