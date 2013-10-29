$ ->
  $('#clothe-id').focus()
  $('#btn-clear').click (e) ->
    e.preventDefault()
    $('#clothes-list ul li').remove()
    $('#action-buttons').hide()
    $('#clothe-id').focus()
  $('#btn-clothe-search').click (e) ->
    $('#clothe-search-form').trigger('submit')
  $('#clothe-search-form').submit (e) ->
    e.preventDefault()
    clothe_id = $('#clothe-id').val()
    $('#clothe-id').val('').focus()
    return unless clothe_id
    $.ajax "/clothes/#{clothe_id}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        return if $("#clothes-list li[data-clothe-id='#{data.id}']").length
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
    unless $('input[name=clothe-id]:checked').val()
      return alert('선택하신 주문상품이 없습니다')
    $('#order-form').submit()
