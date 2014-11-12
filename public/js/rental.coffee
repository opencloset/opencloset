$ ->
  $('#query').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('#clothes-table table tbody tr').remove()
    $('#order-table table tbody tr').remove()
    $('#action-buttons').hide()
    $('#query').focus()
  $('#btn-search').click (e) ->
    $('#search-form').trigger('submit')

  $('#search-form').submit (e) ->
    e.preventDefault()
    query = $('#query').val()
    $('#query').val('').focus()
    return unless query

    #
    # 검색어 길이가 4이면
    #
    if query.length is 4
      #
      # 의류 검색 및 결과 테이블 갱신
      #
      $.ajax "/api/clothes/#{query}.json",
        type: 'GET'
        dataType: 'json'
        success: (data, textStatus, jqXHR) ->
          data.code        = data.code.replace /^0/, ''
          data.categoryStr = OpenCloset.category[ data.category ].str

          return if $("#clothes-table table tbody tr[data-clothes-code='#{data.code}']").length
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
          if jqXHR.status is 404
            OpenCloset.alert 'warning', "#{query} 의류는 찾을 수 없습니다."
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
