// Generated by CoffeeScript 1.6.3
(function() {
  $(function() {
    $('#clothe-id').focus();
    $('#btn-clear').click(function(e) {
      e.preventDefault();
      $('#clothes-list ul li').remove();
      $('#action-buttons').hide();
      return $('#clothe-id').focus();
    });
    $('#btn-clothe-search').click(function(e) {
      return $('#clothe-search-form').trigger('submit');
    });
    $('#clothe-search-form').submit(function(e) {
      var clothe_id;
      e.preventDefault();
      clothe_id = $('#clothe-id').val();
      $('#clothe-id').val('').focus();
      if (!clothe_id) {
        return;
      }
      return $.ajax("/clothes/" + clothe_id + ".json", {
        type: 'GET',
        dataType: 'json',
        success: function(data, textStatus, jqXHR) {
          var $html, compiled;
          if ($("#clothes-list li[data-clothe-id='" + data.id + "']").length) {
            return;
          }
          compiled = _.template($('#tpl-row-checkbox').html());
          $html = $(compiled(data));
          if (/대여가능/.test(data.status)) {
            $html.find('.order-status').addClass('label-success');
          }
          $('#clothes-list ul').append($html);
          return $('#action-buttons').show();
        },
        error: function(jqXHR, textStatus, errorThrown) {
          return alert('error', jqXHR.responseJSON.error);
        },
        complete: function(jqXHR, textStatus) {}
      });
    });
    return $('#action-buttons').on('click', 'button:not(.disabled)', function(e) {
      if (!$('input[name=gid]:checked').val()) {
        return alert('대여자님을 선택해 주세요');
      }
      if (!$('input[name=clothe-id]:checked').val()) {
        return alert('선택하신 주문상품이 없습니다');
      }
      return $('#order-form').submit();
    });
  });

}).call(this);
