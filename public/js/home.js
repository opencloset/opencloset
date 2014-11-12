$(function() {
  var showStatusOnly;
  $('#clothes-id').focus();
  $('#btn-clear').click(function(e) {
    e.preventDefault();
    $('#clothes-table table tbody tr').remove();
    $('#action-buttons').hide();
    return $('#clothes-id').focus();
  });
  $('#btn-clothes-search').click(function(e) {
    return $('#clothes-search-form').trigger('submit');
  });
  $('#clothes-search-form').submit(function(e) {
    var clothes_id;
    e.preventDefault();
    clothes_id = $('#clothes-id').val();
    $('#clothes-id').val('').focus();
    if (!clothes_id) {
      return;
    }
    return $.ajax("/api/clothes/" + clothes_id + ".json", {
      type: 'GET',
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {
        var $html, compiled, html;
        data.code = data.code.replace(/^0/, '');
        data.statusCode = OpenCloset.status[data.status].id;
        if (data.status === '대여중') {
          if ($("#clothes-table table tbody tr[data-order-id='" + data.order.id + "']").length) {
            return;
          }
          compiled = _.template($('#tpl-row-checkbox-clothes-with-order').html());
          $html = $(compiled(data));
          if (data.order.overdue) {
            compiled = _.template($('#tpl-overdue-paragraph').html());
            html = compiled(data);
            $html.find("td:last-child").append(html);
          }
        } else {
          if ($("#clothes-table table tbody tr[data-clothes-code='" + data.code + "']").length) {
            return;
          }
          compiled = _.template($('#tpl-row-checkbox-clothes').html());
          $html = $(compiled(data));
          if (data.status === '대여가능') {
            $('#action-buttons').show();
          }
        }
        $html.find('.order-status').addClass(OpenCloset.status[data.status].css);
        return $("#clothes-table table tbody").append($html);
      },
      error: function(jqXHR, textStatus, errorThrown) {
        return OpenCloset.alert('danger', jqXHR.responseJSON.error);
      },
      complete: function(jqXHR, textStatus) {}
    });
  });
  showStatusOnly = function(code) {
    if (code === 'all') {
      return $(".clothes-status").show();
    } else {
      $(".clothes-status").hide();
      return $(".clothes-status-" + code).show();
    }
  };
  $('#clothes-status-all').click(function(e) {
    return showStatusOnly('all');
  });
  $('#clothes-status-1').click(function(e) {
    return showStatusOnly(1);
  });
  $('#clothes-status-2').click(function(e) {
    return showStatusOnly(2);
  });
  $('#clothes-status-3').click(function(e) {
    return showStatusOnly(3);
  });
  $('#clothes-status-4').click(function(e) {
    return showStatusOnly(4);
  });
  $('#clothes-status-5').click(function(e) {
    return showStatusOnly(5);
  });
  $('#clothes-status-6').click(function(e) {
    return showStatusOnly(6);
  });
  $('#clothes-status-7').click(function(e) {
    return showStatusOnly(7);
  });
  $('#clothes-status-8').click(function(e) {
    return showStatusOnly(8);
  });
  $('#clothes-status-9').click(function(e) {
    return showStatusOnly(9);
  });
  $('#clothes-status-11').click(function(e) {
    return showStatusOnly(11);
  });
  $('#action-buttons li > a').click(function(e) {
    var clothes, status_id;
    clothes = [];
    $('#clothes-table input:checked').each(function(i, el) {
      if ($(el).attr('id') === 'input-check-all') {
        return;
      }
      if ($(el).is(':visible')) {
        return clothes.push($(el).data('clothes-code'));
      }
    });
    clothes = _.uniq(clothes);
    if (!clothes.length) {
      return;
    }
    status_id = OpenCloset.status[this.innerHTML.replace(/^\s+|\s+$/g, "")].id;
    $.ajax("/api/clothes-list.json", {
      type: 'PUT',
      data: $.param({
        code: clothes,
        status_id: status_id
      }, true),
      dataType: 'json',
      success: function(data, textStatus, jqXHR) {
        return $.ajax("/api/clothes-list.json", {
          type: 'GET',
          data: $.param({
            code: clothes
          }, true),
          dataType: 'json',
          success: function(data, textStatus, jqXHR) {
            var code, _i, _len, _results;
            _results = [];
            for (_i = 0, _len = data.length; _i < _len; _i++) {
              clothes = data[_i];
              code = clothes.code.replace(/^0/, '');
              _results.push($("#clothes-table table tbody tr[data-clothes-code='" + code + "'] td:nth-child(3) span.order-status").html(clothes.status).removeClass(function(i, c) {
                return c;
              }).addClass(['order-status', 'label', OpenCloset.status[clothes.status].css].join(' ')));
            }
            return _results;
          },
          error: function(jqXHR, textStatus, errorThrown) {
            return OpenCloset.alert('danger', jqXHR.responseJSON.error);
          }
        });
      },
      error: function(jqXHR, textStatus, errorThrown) {
        return OpenCloset.alert('danger', jqXHR.responseJSON.error);
      }
    });
    return $('#clothes-id').focus();
  });
  return $('#input-check-all').click(function(e) {
    var is_checked;
    is_checked = $('#input-check-all').is(':checked');
    return $(this).closest('thead').next().find('.ace:checkbox:not(:disabled)').prop('checked', is_checked);
  });
});
