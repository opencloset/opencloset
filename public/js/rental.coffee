$ ->
  $('#cloth-id').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('#clothes-list ul li').remove()
    $('#action-buttons').hide()
    $('#cloth-id').focus()
  $('#btn-cloth-search').click (e) ->
    $('#cloth-search-form').trigger('submit')

  #
  # 의류 검색 및 결과 테이블 갱신
  #
  $('#cloth-search-form').submit (e) ->
    e.preventDefault()
    cloth_id = $('#cloth-id').val()
    $('#cloth-id').val('').focus()
    return unless cloth_id
    $.ajax "/clothes/#{cloth_id}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        return if $("#cloth-table table tbody tr[data-cloth-id='#{data.id}']").length
        unless /^(대여중|연체중|부분반납)/.test(data.status)
          compiled = _.template($('#tpl-row-checkbox-enabled').html())
          $html = $(compiled(data))
          if /대여가능/.test(data.status)
            $html.find('.order-status').addClass('label-success')
          $('#cloth-table table tbody').append($html)
          $('#action-buttons').show()
        else
          compiled = _.template($('#tpl-row-checkbox-disabled').html())
          $html = $(compiled(data))
          if /연체중/.test(data.status)
            $html.find('.order-status').addClass('label-important')
          $("#cloth-table table tbody").append($html)
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
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
  $('#action-buttons').on 'click', 'button:not(.disabled)', (e) ->
    unless $('input[name=gid]:checked').val()
      return alert('대여자님을 선택해 주세요')
    unless $('input[name=cloth-id]:checked').val()
      return alert('선택하신 주문상품이 없습니다')
    $('#order-form').submit()
