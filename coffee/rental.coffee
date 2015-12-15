$ ->
  $('#clothes-id').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('#clothes-table table tbody tr').remove()
    $('#order-table table tbody tr').remove()
    $('#action-buttons').hide()
    $('#clothes-id').focus()
  $('#btn-search').click (e) ->
    $('#search-form').trigger('submit')

  #
  # 대여 희망 품목을 코드가 아닌 레이블로 표시
  #
  $('.pre_category').each (i, el) ->
    value = $(el).html()
    return unless value

    mapped_values = []
    for i in value.split(',')
      item = OpenCloset.category[i]
      continue unless item
      str = item.str.replace /^\s+|\s+$/, ""
      continue if str is ''
      mapped_values.push str
      $(el).html( mapped_values.join(',') )

  $('#search-form').submit (e) ->
    e.preventDefault()
    clothes_id = $('#clothes-id').val().toUpperCase()
    $('#clothes-id').val('').focus()
    return unless clothes_id

    #
    # 의류 검색 및 결과 테이블 갱신
    #
    $.ajax "/api/clothes/#{clothes_id}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        data.code        = data.code.replace /^0/, ''
        data.categoryStr = OpenCloset.category[ data.category ].str

        return if $("#clothes-table table tbody tr[data-clothes-code='#{data.code}']").length

        data.count = $("#clothes-table table tbody tr").length + 1
        if data.status is '대여중'
          compiled = _.template($('#tpl-row-checkbox-disabled-with-order').html())
          $html = $(compiled(data))
          if data.order.overdue
            compiled = _.template($('#tpl-overdue-paragraph').html())
            html     = compiled(data)
            $html.find("td:last-child").append(html)
        else if data.status is '대여가능'
          compiled = _.template($('#tpl-row-checkbox-enabled').html())
          $html = $(compiled(data))
          $('#action-buttons').show() if data.status is '대여가능'
        else
          compiled = _.template($('#tpl-row-checkbox-disabled-without-order').html())
          $html = $(compiled(data))

        $html.find('.order-status').addClass OpenCloset.status[ data.status ].css
        $("#clothes-table table tbody").append($html)
      error: (jqXHR, textStatus, errorThrown) ->
        msg = "#{clothes_id}: "
        switch jqXHR.status
          when 400
            msg += '의류 코드가 정확하지 않습니다.'
          when 404
            msg += '의류 코드가 없습니다.'
          else
            msg += '알 수 없는 오류입니다.'
        OpenCloset.alert 'warning', msg
      complete: (jqXHR, textStatus) ->

  #
  # 의류 검색 결과 테이블에서 모든 항목 선택 및 취소
  #
  $('#input-check-all').click (e) ->
    is_checked = $('#input-check-all').is(':checked')
    $(@).closest('thead').next().find('.ace:checkbox:not(:disabled)').prop('checked', is_checked)

  #
  # 대여 버튼 클릭
  #
  $('#action-buttons').click (e) ->
    order = $('input[name=id]:checked').val()

    clothes = []
    $('input[name=clothes_code]:checked').each (i, el) ->
      return if $(el).attr('id') is 'input-check-all'
      clothes.push($(el).data('clothes-code'))
    clothes = _.uniq(clothes)

    return OpenCloset.alert('danger', '대여할 주문서를 선택해 주세요') unless order
    return OpenCloset.alert('danger', '대여할 옷을 선택해 주세요.')    unless clothes

    $('#order-form').submit()
