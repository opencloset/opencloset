$ ->
  $('#cloth-id').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('#cloth-table table tbody tr').remove()
    $('#action-buttons').hide()
    $('#cloth-id').focus()
  $('#btn-cloth-search').click (e) ->
    $('#cloth-search-form').trigger('submit')
  $('#cloth-search-form').submit (e) ->
    e.preventDefault()
    cloth_id = $('#cloth-id').val()
    $('#cloth-id').val('').focus()
    return unless cloth_id
    $.ajax "/clothes/#{cloth_id}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        console.log data
        console.log data.status
        if data.status is '대여가능'
          return if $("#cloth-table table tbody tr[data-cloth-id='#{data.id}']").length
          compiled = _.template($('#tpl-row-checkbox-enabled').html())
          $html = $(compiled(data))
          if /대여가능/.test(data.status)
            $html.find('.order-status').addClass('label-success')
          $('#cloth-table table tbody').append($html)
          $('#action-buttons').show()
        else
          return if $("#cloth-table table tbody tr[data-order-id='#{data.order_id}']").length
          compiled = _.template($('#tpl-row-checkbox-disabled').html())
          $html = $(compiled(data))
          if /대여중/.test(data.status)
            $html.find('.order-status').addClass('label-important')
          if data.overdue
            compiled = _.template($('#tpl-overdue-paragraph').html())
            html     = compiled(data)
            $html.find("td:last-child").append(html)
          $("#cloth-table table tbody").append($html)
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->

  $('#action-buttons').on 'click', 'button:not(.disabled)', (e) ->
    $this = $(@)
    $this.addClass('disabled')
    status  = $this.data('status')
    clothes = []
    alert 'hello'
    $('#cloth-table input:checked').each (i, el) ->
      clothes.push($(el).data('cloth-id'))
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
    $('#cloth-id').focus()

  #
  # 의류 검색 결과 테이블에서 모든 항목 선택 및 취소
  #
  $('#input-check-all').click (e) ->
    is_checked = $('#input-check-all').is(':checked')
    $(@).closest('thead').next().find('.ace:checkbox:not(:disabled)').prop('checked', is_checked)
