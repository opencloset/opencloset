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
    clothes_id = $('#clothes-id').val()
    $('#clothes-id').val('').focus()
    return unless clothes_id
    $.ajax "/api/clothes/#{clothes_id}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        console.log data
        data.code = data.code.replace /^0/, ''
        if data.status is '대여중'
          return if $("#clothes-table table tbody tr[data-order-id='#{data.order.id}']").length
          compiled = _.template($('#tpl-row-checkbox-clothes-with-order').html())
          $html = $(compiled(data))
          $html.find('.order-status').addClass('label-important')
          if data.order.overdue
            compiled = _.template($('#tpl-overdue-paragraph').html())
            html     = compiled(data)
            $html.find("td:last-child").append(html)
          $("#clothes-table table tbody").append($html)
        else
          return if $("#clothes-table table tbody tr[data-clothes-code='#{data.code}']").length
          compiled = _.template($('#tpl-row-checkbox-clothes').html())
          $html = $(compiled(data))
          $('#clothes-table table tbody').append($html)
          if data.status is '대여가능'
            $html.find('.order-status').addClass('label-success')
            $('#action-buttons').show()
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->

  $('#action-buttons').on 'click', 'button:not(.disabled)', (e) ->
    $this = $(@)
    $this.addClass('disabled')
    status  = $this.data('status')
    clothes = []
    alert 'hello'
    $('#clothes-table input:checked').each (i, el) ->
      clothes.push($(el).data('clothes-id'))
      console.log $(el)
      console.log $(i)
    alert 'world'
    clothes = _.uniq(clothes)
    $.ajax "/clothes.json",
      type: 'PUT'
      data: { status: status, clothes: clothes.join() }
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $('#clothes-list input:checked').each (i, el) ->
          $(el).closest('.row-checkbox').remove()
        unless $('#clothes-list .row-checkbox').length
          $('#action-buttons').hide()
        alert('success', "#{clothes.length}개의 항목이 #{status} (으)로 변경되었습니다")
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
    $('#clothes-id').focus()

  #
  # 의류 검색 결과 테이블에서 모든 항목 선택 및 취소
  #
  $('#input-check-all').click (e) ->
    is_checked = $('#input-check-all').is(':checked')
    $(@).closest('thead').next().find('.ace:checkbox:not(:disabled)').prop('checked', is_checked)
