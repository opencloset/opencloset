$ ->
  $('#cloth-id').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('#clothes-list ul li').remove()
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
        return if $("#clothes-list li[data-cloth-id='#{data.id}']").length
        compiled = _.template($('#tpl-row-checkbox').html())
        $html = $(compiled(data))
        if /대여가능/.test(data.status)
          $html.find('.order-status').addClass('label-success')
        $('#clothes-list ul').append($html)
        $('#action-buttons').show()
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->

  $('#action-buttons').on 'click', 'button:not(.disabled)', (e) ->
    unless $('input[name=gid]:checked').val()
      return alert('대여자님을 선택해 주세요')
    unless $('input[name=cloth-id]:checked').val()
      return alert('선택하신 주문상품이 없습니다')
    $('#order-form').submit()
