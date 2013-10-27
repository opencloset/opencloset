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
        unless /^(대여중|연체중)/.test(data.status)
          return if $("#clothes-list li[data-clothe-id='#{data.id}']").length
          compiled = _.template($('#tpl-row-checkbox').html())
          $html = $(compiled(data))
          if /대여가능/.test(data.status)
            $html.find('.order-status').addClass('label-success')
          $('#clothes-list ul').append($html)
          $('#action-buttons').show()
        else
          return if $("#clothes-list li[data-order-id='#{data.order_id}']").length
          compiled = _.template($('#tpl-row').html())
          $html = $(compiled(data))
          if /연체중/.test(data.status)
            $html.find('.order-status').addClass('label-important')
          if data.overdue
            compiled = _.template($('#tpl-overdue-paragraph').html())
            html     = compiled(data)
            $html.append(html)
          $('#clothes-list ul').append($html)
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->

  $('#action-buttons').on 'click', 'button:not(.disabled)', (e) ->
    $this = $(@)
    $this.addClass('disabled')
    status  = $this.data('status')
    clothes = []
    $('#clothes-list input:checked').each (i, el) ->
      clothes.push($(el).data('clothe-id'))
    clothes = _.uniq(clothes)
    $.ajax "/clothes.json",
      type: 'PUT'
      data: { status: status, clothes: clothes.join() }
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $('#clothes-list input:checked').each (i, el) ->
          $(el).closest('.row-checkbox').remove()
        unless $('#clothes-list .row-checkbox')
          $('#action-buttons').hide()
        alert('success', "#{clothes.length}개의 항목이 #{status} (으)로 변경되었습니다")
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
    $('#clothe-id').focus()
