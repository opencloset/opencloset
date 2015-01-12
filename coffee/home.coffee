$ ->
  $('#clothes-id').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('#clothes-table table tbody tr').remove()
    $('#action-buttons').hide()
    $('#clothes-id').focus()
  $('#btn-clothes-search').click (e) ->
    $('#clothes-search-form').trigger('submit')

  #
  # 옷 검색 후 테이블에 추가
  #
  $('#clothes-search-form').submit (e) ->
    e.preventDefault()
    clothes_id = $('#clothes-id').val().toUpperCase()
    $('#clothes-id').val('').focus()
    return unless clothes_id
    $.ajax "/api/clothes/#{clothes_id}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        data.code = data.code.replace /^0/, ''
        data.statusCode = OpenCloset.status[ data.status ].id
        if data.status is '대여중'
          return if $("#clothes-table table tbody tr[data-order-id='#{data.order.id}']").length
          compiled = _.template($('#tpl-row-checkbox-clothes-with-order').html())
          $html = $(compiled(data))
          if data.order.overdue
            compiled = _.template($('#tpl-overdue-paragraph').html())
            html     = compiled(data)
            $html.find("td:last-child").append(html)
        else
          return if $("#clothes-table table tbody tr[data-clothes-code='#{data.code}']").length
          compiled = _.template($('#tpl-row-checkbox-clothes').html())
          $html = $(compiled(data))
          $('#action-buttons').show() if data.status is '대여가능'

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
  # 테이블의 의류 목록을 상태별로 분리해서 표시
  #
  showStatusOnly = (code) ->
    if code == 'all'
      $(".clothes-status").show()
    else
      $(".clothes-status").hide()
      $(".clothes-status-#{code}").show()

  $('#clothes-status-all').click (e) -> showStatusOnly 'all'
  $('#clothes-status-1').click (e)   -> showStatusOnly 1
  $('#clothes-status-2').click (e)   -> showStatusOnly 2
  $('#clothes-status-3').click (e)   -> showStatusOnly 3
  $('#clothes-status-4').click (e)   -> showStatusOnly 4
  $('#clothes-status-5').click (e)   -> showStatusOnly 5
  $('#clothes-status-6').click (e)   -> showStatusOnly 6
  $('#clothes-status-7').click (e)   -> showStatusOnly 7
  $('#clothes-status-8').click (e)   -> showStatusOnly 8
  $('#clothes-status-9').click (e)   -> showStatusOnly 9
  $('#clothes-status-11').click (e)  -> showStatusOnly 11
  $('#clothes-status-41').click (e)  -> showStatusOnly 41
  $('#clothes-status-42').click (e)  -> showStatusOnly 42

  #
  # 의류 목록에서 선택한 항목의 상태 변경
  #
  $('#action-buttons li > a').click (e) ->
    clothes = []
    $('#clothes-table input:checked').each (i, el) ->
      return if $(el).attr('id') is 'input-check-all'
      clothes.push($(el).data('clothes-code')) if $(el).is(':visible')
    clothes = _.uniq(clothes)
    return unless clothes.length

    status_id = OpenCloset.status[ this.innerHTML.replace /^\s+|\s+$/g, "" ].id

    #
    # 체크한 의류 상태를 변경하는 api 호출
    #
    $.ajax "/api/clothes-list.json",
      type: 'PUT'
      data: $.param( { code: clothes, status_id: status_id }, true)
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        #
        # 상태 변경이 성공한 경우 해당 항목의 상태 레이블을 갱신
        #
        $.ajax "/api/clothes-list.json",
          type: 'GET'
          data: $.param( { code: clothes }, true)
          dataType: 'json'
          success: (data, textStatus, jqXHR) ->
            for clothes in data
              code = clothes.code.replace /^0/, ''
              $("#clothes-table table tbody tr[data-clothes-code='#{code}'] td:nth-child(3) span.order-status")
                .html(clothes.status)
                .removeClass( (i, c) -> c )
                .addClass [ 'order-status', 'label', OpenCloset.status[ clothes.status ].css ].join(' ')
          error: (jqXHR, textStatus, errorThrown) ->
            OpenCloset.alert('danger', jqXHR.responseJSON.error)
      error: (jqXHR, textStatus, errorThrown) ->
        OpenCloset.alert('danger', jqXHR.responseJSON.error)
    $('#clothes-id').focus()

  #
  # 의류 검색 결과 테이블에서 모든 항목 선택 및 취소
  #
  $('#input-check-all').click (e) ->
    is_checked = $('#input-check-all').is(':checked')
    $(@).closest('thead').next().find('.ace:checkbox:not(:disabled)').prop('checked', is_checked)
