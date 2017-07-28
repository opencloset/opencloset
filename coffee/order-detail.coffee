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
        location.reload(true) if reload

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
  $('.editable').on 'save', (e, params) ->
    location.reload()

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
    $('#form-returned').submit()

  $('#btn-return-partial').click (e) ->
    return if $(@).hasClass('disabled')
    $('#table-order-details .order-detail-stage .fa-check-square-o').each (i, el) ->
      code = $(el).parent().data('code')
      $('<input>').attr
        type: 'hidden'
        name: 'codes'
        value: code
      .appendTo('#form-returned')

    $('#form-returned').submit()

  $('#btn-late-fee-discount').click (e) ->
    late_fee = $('#late-fee').data('late-fee')
    $(@).parent().find('input[name=late_fee_discount]').val(late_fee)
    $('#late-fee').html('0')

  $('#toggle-ignore-sms').change ->
    ignore = if $(@).prop('checked') then '1' else '0'
    $('#form-returned input[name=ignore_sms]').val(ignore)

  $('#form-late-fee-discount').submit (e) ->
    e.preventDefault()
    $(@).find('input[name=late_fee_discount]').trigger('change')

  $('#form-late-fee-discount input[name=late_fee_discount]').on 'change', (e) ->
    late_fee = $('#late-fee').data('late-fee')
    discount = $(@).val() or 0
    late_fee = late_fee - discount
    $('#late-fee').html(OpenCloset.commify(late_fee))
    $('#form-returned input[name=late_fee_discount]').val(discount)

  $('#form-coupon-code').on 'submit', (e) ->
    e.preventDefault()
    $form = $(@)
    $.ajax $form.prop('action'),
      type: 'POST'
      dataType: 'json'
      data: $form.serialize()
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        unless jqXHR.responseJSON.order
          return $.growl.error({ message: jqXHR.responseJSON.error.str })

        anchor = "<a href=\"#{jqXHR.responseJSON.order}\">주문서 바로가기</a>"
        OpenCloset.alert("#{jqXHR.responseJSON.error} #{anchor}")
      complete: (jqXHR, textStatus) ->

  $('#btn-rental-reset').click (e) ->
    e.preventDefault()
    return unless confirm '정말 새로 주문하시겠습니까?'
    $form = $(@).closest('form')
    $form.find('#rental-reset').val('1')
    $form.submit()

  $('[data-toggle="tooltip"]').tooltip()
  $('.action-toggle input[data-toggle="toggle"]').on 'change', (e) ->
    $this = $(@)
    name  = $this.prop('name')
    url   = $this.data('update-url')
    label = $this.data('on')

    return unless name
    return unless url

    data = {}
    checked = $this.prop('checked')
    data[name] = if checked then '1' else '0'

    $.ajax url,
      type: 'PUT'
      dataType: 'json'
      data: data
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ title: "알림", message: "#{label}이(가) 수정되었습니다." })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error })

  $('.jobwing-actions .dropdown-menu a.btn-jobwing').click (e) ->
    e.preventDefault()
    $this = $(@)

    $.ajax $this.prop('href'),
      type: 'POST'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ title: "연장신청 되었습니다.", message: "취업날개 서비스에서 연장횟수를 확인해주세요." })

        n = parseInt($this.data('qty'))
        $('#datepicker-user-target-date').datepicker('setDate', "+#{n * 4}d")

        if $('#datepicker-target-date').length
          $('#datepicker-target-date').datepicker('setDate', "+#{n * 4}d")
        else
          order_id = $.trim($('#order-id').text())
          user_target_date = $('#datepicker-user-target-date').datepicker('getFormattedDate')
          $.ajax "/api/order/#{order_id}",
            type: 'PUT'
            dataType: 'json'
            data: { target_date: user_target_date }
            success: (data, textStatus, jqXHR) ->
              location.reload()
            error: (jqXHR, textStatus, errorThrown) ->
              $.growl.error({ message: jqXHR.responseJSON.error })
            complete: (jqXHR, textStatus) ->

      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ message: jqXHR.responseJSON.error })
