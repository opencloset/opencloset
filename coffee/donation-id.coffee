$ ->
  # TODO: prevent double click
  $('#donation .btn').click (e) ->
    e.preventDefault()
    $this = $(@)
    url = $this.closest('form').prop('action')
    message = $this.closest('form').find('textarea').val()
    return unless message
    $.ajax url,
      type: 'PUT'
      data: { message: message }
      success: (data, textStatus, jqXHR) ->
        OpenCloset.alert '기증 메세지가 수정되었습니다.'
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $.facebox.settings.loadingImage = '/lib/facebox/loading.gif'
  $.facebox.settings.closeImage = '/lib/facebox/closelabel.png'
  $('a[rel*=facebox]').facebox()
  $(document).bind 'reveal.facebox', ->
    $('#facebox #username').focus()

  $('#facebox').on 'click', 'button', (e) ->
    e.preventDefault()
    $this = $(@)
    url = $this.closest('form').prop('action')
    q = $this.closest('form').find('#username').val()
    $.ajax url,
      type: 'GET'
      data: { q: q }
      success: (data, textStatus, jqXHR) ->
        compiledItem = _.template( $('#tpl-user-list-item').html() )
        $listgroup = $this.closest('div').find('.list-group').empty()
        _.each data, (user) ->
          $listgroup.append(compiledItem(user))
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->

  $('#facebox').on 'click', '.user-list-item', (e) ->
    e.preventDefault()
    user_id = $(@).data('id')
    username = $(@).data('username')
    $.ajax "/api#{location.pathname}.json",
      type: 'PUT'
      data: { user_id: user_id }
      success: (data, textStatus, jqXHR) ->
        OpenCloset.alert '기증자가 수정되었습니다.'
        $('#donation h2 > a').prop('href', "/user/#{data.user_id}").html(username)
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
        $.facebox.close()

  $('span.order-status.label').each (i, el) ->
    $(el).addClass OpenCloset.status[ $(el).data('status') ].css

  $('#clothes-bucket span').dblclick (e) ->
    e.preventDefault()
    $this = $(@)
    code = $this.data('clothes-code')
    $.ajax "/api/clothes/#{code}.json",
      type: 'PUT'
      data: { donation_id: $('#donation').data('donation-id') }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        console.log textStatus
      complete: (jqXHR, textStatus) ->
