$ ->
  origin_fee = $('#input-price').val() or 0
  $('#input-target-date').datepicker
    format: 'yyyy-mm-dd'
    autoclose: true
    startDate: new Date()
    language: 'kr'
  .on 'changeDate', (e) ->
    additional_days = overdue_calc(new Date(), $('#input-target-date').datepicker('getDate'))
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

  clothes = []
  $('.input-clothe').each (i, el) ->
    clothes.push $(el).data('clothe-no')

  $('#input-clothe-no').focus()

  $('#btn-clothe-no').click (e) ->
    $('#form-clothe-no').trigger('submit')
  $('#form-clothe-no').submit (e) ->
    e.preventDefault()
    clothe_no = $('#input-clothe-no').val()
    $('#input-clothe-no').val('').focus()
    found = _.find clothes, (val) ->
      val is clothe_no
    return alert("Not found #{clothe_no}") unless found
    $(".input-clothe[data-clothe-no=#{found}]").attr('checked', true)

  $('#form-return').submit (e) ->
    clothes_no = []
    $('.input-clothe:not(:checked)').each (i, el) ->
      clothes_no.push $(el).data('clothe-no')
    console.log $.putUrlVars({ clothes : clothes_no.join() })
    if $('.input-clothe').length isnt $('.input-clothe:checked').length
      if confirm('반납품목이 제대로 체크 되지 않았습니다. 계속하시겠습니까?')
        action = $('#form-return').attr('action')
        $('#form-return').attr('action', "#{action}?#{$.putUrlVars({ missing_clothes : clothes_no.join() })}")
        return true
      else
        return false
    return true
