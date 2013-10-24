$ ->
  $('#clothe-id').focus()
  $('#btn-clothe-search').click (e) ->
    $('#clothe-search-form').trigger('submit')
  $('#clothe-search-form').submit (e) ->
    e.preventDefault()
    $('#clothe-search-form p.text-error').text('')
    clothe_id = $('#clothe-id').val()
    $('#clothe-id').val('').focus()
    return unless clothe_id
    $.ajax "/clothes/#{clothe_id}.json",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        if /대여가능/.test(data.status)
          compiled = _.template($('#tpl-rent-available').html())
          html = $(compiled(data))
          $('#clothes-list').append(html)
          return

        compiled = _.template($('#tpl-li').html())
        $html = $(compiled(data))
        if /연체중/.test(data.status)
          $html.find('.order-status').addClass('label-important')
        if data.overdue
          compiled = _.template($('#tpl-overdue-paragraph').html())
          html     = compiled(data)
          $html.append(html)
        $('#clothes-list').append($html)
      error: (jqXHR, textStatus, errorThrown) ->
        $('#clothe-search-form p.text-error').text(jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->
