$ ->
  $(".chosen-select").chosen({ width: '50%' }).change (e) ->
    $this = $(@)
    name  = $this.closest('select').prop('name')
    label = $this.data('label')
    val   = $this.val()
    url   = $this.data('update-url')

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

  $('#datepicker-user-target-date').datepicker
    language: 'ko'
    autoclose: true
    todayHighlight: true
  .on 'changeDate', (e) ->
    val = $(@).datepicker('getFormattedDate')
    url = $(@).data('update-url')
    $.ajax url,
      type: 'PUT'
      dataType: 'json'
      data: { user_target_date: val }
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ title: "알림", message: "반납희망일이 수정되었습니다." })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
