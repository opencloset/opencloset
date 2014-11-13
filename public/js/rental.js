$(function() {
  $('#query').focus();
  $('#btn-clear').click(function(e) {
    e.preventDefault();
    $('#clothes-table table tbody tr').remove();
    $('#order-table table tbody tr').remove();
    $('#action-buttons').hide();
    return $('#query').focus();
  });
  $('#btn-search').click(function(e) {
    return $('#search-form').trigger('submit');
  });
  $('#search-form').submit(function(e) {
    var query;
    e.preventDefault();
    query = $('#query').val();
    $('#query').val('').focus();
    if (!query) {
      return;
    }
    if (query.length === 4) {
      return $.ajax("/api/clothes/" + query + ".json", {
        type: 'GET',
        dataType: 'json',
        success: function(data, textStatus, jqXHR) {
          var $html, compiled, html;
          data.code = data.code.replace(/^0/, '');
          data.categoryStr = OpenCloset.category[data.category].str;
          if ($("#clothes-table table tbody tr[data-clothes-code='" + data.code + "']").length) {
            return;
          }
          if (data.status === '대여중') {
            compiled = _.template($('#tpl-row-checkbox-disabled-with-order').html());
            $html = $(compiled(data));
            if (data.order.overdue) {
              compiled = _.template($('#tpl-overdue-paragraph').html());
              html = compiled(data);
              $html.find("td:last-child").append(html);
            }
          } else if (data.status === '대여가능') {
            compiled = _.template($('#tpl-row-checkbox-enabled').html());
            $html = $(compiled(data));
            if (data.status === '대여가능') {
              $('#action-buttons').show();
            }
          } else {
            compiled = _.template($('#tpl-row-checkbox-disabled-without-order').html());
            $html = $(compiled(data));
          }
          $html.find('.order-status').addClass(OpenCloset.status[data.status].css);
          return $("#clothes-table table tbody").append($html);
        },
        error: function(jqXHR, textStatus, errorThrown) {
          if (jqXHR.status === 404) {
            return OpenCloset.alert('warning', "" + query + " 의류는 찾을 수 없습니다.");
          }
        },
        complete: function(jqXHR, textStatus) {}
      });
    }
  });
  $('#input-check-all').click(function(e) {
    var is_checked;
    is_checked = $('#input-check-all').is(':checked');
    return $(this).closest('thead').next().find('.ace:checkbox:not(:disabled)').prop('checked', is_checked);
  });
  return $('#action-buttons').click(function(e) {
    var clothes, order;
    order = $('input[name=id]:checked').val();
    clothes = [];
    $('input[name=clothes_code]:checked').each(function(i, el) {
      if ($(el).attr('id') === 'input-check-all') {
        return;
      }
      return clothes.push($(el).data('clothes-code'));
    });
    clothes = _.uniq(clothes);
    if (!order) {
      return OpenCloset.alert('danger', '대여할 주문서를 선택해 주세요');
    }
    if (!clothes) {
      return OpenCloset.alert('danger', '대여할 옷을 선택해 주세요.');
    }
    return $('#order-form').submit();
  });
});
