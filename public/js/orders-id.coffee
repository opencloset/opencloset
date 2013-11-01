$ ->
  origin_fee = $('#input-price').val() or 0
  $('#input-target-date').datepicker
    format: 'yyyy-mm-dd'
    autoclose: true
    startDate: new Date()
    language: 'kr'
  .on 'changeDate', (e) ->
    additional_days = overdue_calc(new Date(), $('#input-target-date').datepicker('getDate'))
    console.log additional_days
    additional_fee = additional_days * origin_fee * 0.2
    $('#input-price').val(parseInt(origin_fee) + parseInt(additional_fee))

  overdue_calc = (target_dt, return_dt) ->
    DAY_AS_SECONDS = 60 * 60 * 24
    dur = return_dt.getTime() - (DAY_AS_SECONDS * 1000 * 2) - target_dt.getTime()
    return 0 if dur < 0
    parseInt(dur / 1000 / DAY_AS_SECONDS)

  $('#btn-order-cancel:not(.disabled)').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    $.ajax "#{$this.attr('href')}.json",
      type: 'DELETE'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        _alert('주문이 취소 되었습니다')
        location.href = '/'
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
