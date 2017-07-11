$.fn.editable.defaults.mode = 'inline'
$ ->
  $(".chosen-select").chosen({ width: '50%' }).change (e) ->
    $this  = $(@)
    name   = $this.closest('select').prop('name')
    label  = $this.data('placeholder')
    val    = $this.val()
    url    = $this.data('update-url')
    reload = $this.data('reload')

    param = {}
    param[name] = val

    $.ajax url,
      type: 'PUT'
      data: param
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ title: "알림", message: "#{label}(이)가 수정되었습니다." })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        location.reload() if reload

  $('#btn-ignore-sms:not(.disabled)').click ->
    $this = $(@)
    $this.addClass('disabled')

    $this.toggleClass('btn-default btn-success')
    ignore_sms = if $this.hasClass('btn-success') then 0 else 1
    $this.text if ignore_sms then 'off' else 'on'
    url = $this.data('update-url')
    $.ajax url,
      type: 'PUT'
      dataType: 'json'
      data: { ignore_sms: ignore_sms }
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ title: "알림", message: "연체문자전송이 수정되었습니다." })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  $('#datepicker-target-date,#datepicker-user-target-date').datepicker
    language: 'ko'
    autoclose: true
    todayHighlight: true
  .on 'changeDate', (e) ->
    name  = $(@).prop('name')
    label = $(@).prop('placeholder')
    val   = $(@).datepicker('getFormattedDate')
    url   = $(@).data('update-url')

    data = {}
    data[name] = val

    $.ajax url,
      type: 'PUT'
      dataType: 'json'
      data: data
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ title: "알림", message: "#{label}이 수정되었습니다." })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->

  $('.btn-edit').click (e) ->
    target = $(@).data('target-id')
    $("##{target}").toggleClass('hide')

  $('.btn-cancel').click (e) ->
    $(@).closest('form').toggleClass('hide')

  $('.panel-body').on 'submit', 'form', (e) ->
    e.preventDefault()
    url = $(@).prop('action')
    $.ajax url,
      type: 'PUT'
      dataType: 'json'
      data: $(@).serialize()
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->

  $('.editable').editable()
  $('time.timeago').timeago()
  $('[data-toggle="tooltip"]').tooltip()
  $('#calc-date').datepicker
    language: 'ko'
    autoclose: true
    todayHighlight: true
  .on 'changeDate', (e) ->
    val = $(@).datepicker('getFormattedDate')
    $('#form-returned input[name=return_date]').val(val)

    url = $(@).data('fetch-url')
    $.ajax "#{url}?return_date=#{val}",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $('#late-fee-tip').attr('data-original-title', data.formatted.tip).tooltip('fixTitle')
        $('#late-fee').text(data.formatted.late_fee).data('late-fee', data.late_fee)
        $.growl.notice({ title: "알림", message: " 연체/연장료가 수정되었습니다." })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->

  $('.order-detail-stage').on 'click', '.fa-square-o,.fa-check-square-o', (e) ->
    $(@).toggleClass('fa-square-o')
    $(@).toggleClass('fa-check-square-o')

    checked   = $('#table-order-details .fa-check-square-o').length
    unchecked = $('#table-order-details .fa-square-o').length

    if unchecked and checked
      $('#btn-return-partial').removeClass('disabled')
      $('#btn-return-all').addClass('disabled')
    else if unchecked
      $('#btn-return-partial').addClass('disabled')
      $('#btn-return-all').addClass('disabled')
    else
      $('#btn-return-partial').addClass('disabled')
      $('#btn-return-all').removeClass('disabled')

  $('#form-clothes-code').submit (e) ->
    e.preventDefault()

    $input = $('#input-code')
    code = $input.val()
    $input.val('')
    return unless code

    code = code.toUpperCase()
    $("#clothes-code-#{code} .fa").trigger('click')

  $('#btn-return-all').click (e) ->
    return if $(@).hasClass('disabled')
    discount = $('#form-late-fee-discount input[name=late_fee_discount]').val()
    $('#form-returned input[name=late_fee_discount]').val(discount)
    ignore = if $('#toggle-ignore-sms').prop('checked') then '1' else '0'
    $('#form-returned input[name=ignore_sms]').val(ignore)
    $('#form-returned').submit()

  $('#btn-late-fee-discount').click (e) ->
    late_fee = $('#late-fee').data('late-fee')
    $(@).parent().find('input[name=late_fee_discount]').val(late_fee)

  $('#toggle-ignore-sms').change ->
    val = if $(@).prop('checked') then '1' else '0'
