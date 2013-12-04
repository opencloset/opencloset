$ ->
  $('#clothes-id').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('#clothes-table table tbody tr').remove()
    $('#action-buttons').hide()
    $('#clothes-id').focus()
  $('#btn-clothes-search').click (e) ->
    $('#clothes-search-form').trigger('submit')

  getStatusCss = (status) ->
    switch status
      when '대여가능'   then css = 'label-success'
      when '대여중'     then css = 'label-important'
      when '대여불가'   then css = 'label-inverse'
      when '예약'       then css = 'label-inverse'
      when '세탁'       then css = 'label-inverse'
      when '수선'       then css = 'label-inverse'
      when '분실'       then css = 'label-inverse'
      when '폐기'       then css = 'label-inverse'
      when '반납'       then css = 'label-inverse'
      when '부분반납'   then css = 'label-warning'
      when '반납배송중' then css = 'label-warning'
      else                   css = ''
    return css

  getStatusId = (status) ->
    switch status
      when '대여가능'   then id = 1
      when '대여중'     then id = 2
      when '대여불가'   then id = 3
      when '예약'       then id = 4
      when '세탁'       then id = 5
      when '수선'       then id = 6
      when '분실'       then id = 7
      when '폐기'       then id = 8
      when '반납'       then id = 9
      when '부분반납'   then id = 10
      when '반납배송중' then id = 11
      else                   id = undef
    return id

  #
  # 옷 검색 후 테이블에 추가
  #
  $('#clothes-search-form').submit (e) ->
    e.preventDefault()
    clothes_id = $('#clothes-id').val()
    $('#clothes-id').val('').focus()
    return unless clothes_id
    $.ajax "/api/clothes/#{clothes_id}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        data.code = data.code.replace /^0/, ''
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

        $html.find('.order-status').addClass(getStatusCss data.status)
        $("#clothes-table table tbody").append($html)
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->

  #
  # 의류 목록에서 선택한 항목의 상태 변경
  #
  $('#action-buttons li > a').click (e) ->
    clothes = []
    $('#clothes-table input:checked').each (i, el) ->
      return if $(el).attr('id') is 'input-check-all'
      clothes.push($(el).data('clothes-code'))
    clothes = _.uniq(clothes)
    return unless clothes.length

    status_id = getStatusId( this.innerHTML.replace /^\s+|\s+$/g, "" )

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
                .addClass [ 'order-status', 'label', getStatusCss(clothes.status) ].join(' ')
          error: (jqXHR, textStatus, errorThrown) ->
            alert('error', jqXHR.responseJSON.error)
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
    $('#clothes-id').focus()

  #
  # 의류 검색 결과 테이블에서 모든 항목 선택 및 취소
  #
  $('#input-check-all').click (e) ->
    is_checked = $('#input-check-all').is(':checked')
    $(@).closest('thead').next().find('.ace:checkbox:not(:disabled)').prop('checked', is_checked)
