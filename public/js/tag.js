$(function() {
  var makeEditable;
  $('#query').focus();
  $('#btn-tag-add').click(function(e) {
    return $('#add-form').trigger('submit');
  });
  $('#add-form').submit(function(e) {
    var base_url, query;
    e.preventDefault();
    query = $('#query').val();
    $('#query').val('').focus();
    if (!query) {
      return;
    }
    base_url = $('#tag-data').data('base-url');
    return $.ajax("" + base_url + ".json", {
      type: 'POST',
      data: {
        name: query
      },
      success: function(data, textStatus, jqXHR) {
        var compiled, html;
        compiled = _.template($('#tpl-tag').html());
        html = $(compiled(data));
        $("#tag-table table tbody").append(html);
        return makeEditable("#tag-id-" + data.id);
      },
      error: function(jqXHR, textStatus, errorThrown) {
        var msg;
        msg = jqXHR.responseJSON.error.str;
        switch (jqXHR.status) {
          case 400:
            if (msg === 'duplicate tag.name') {
              msg = "\"" + query + "\" 태그가 이미 존재합니다.";
            }
        }
        return OpenCloset.alert('danger', msg);
      }
    });
  });
  $('.btn-tag-remove').click(function(e) {
    var base_url, tag_id;
    tag_id = $(this).data('tag-id');
    if (!tag_id) {
      return;
    }
    base_url = $('#tag-data').data('base-url');
    return $.ajax("" + base_url + "/" + tag_id + ".json", {
      type: 'DELETE',
      success: function(data, textStatus, jqXHR) {
        return $(".tag-id-" + data.id).remove();
      },
      error: function(jqXHR, textStatus, errorThrown) {
        var msg;
        msg = jqXHR.responseJSON.error.str;
        switch (jqXHR.status) {
          case 404:
            msg = "\"" + query + "\" 태그를 찾을 수 없습니다.";
        }
        return OpenCloset.alert('danger', msg);
      }
    });
  });
  makeEditable = function(el) {
    var id, params;
    params = {
      mode: 'inline',
      showbuttons: 'true',
      emptytext: '비어있음',
      url: function(params) {
        var base_url, data;
        if (!params.value) {
          return OpenCloset.alert('danger', '변경할 태그 이름을 입력하세요.');
        }
        base_url = $('#tag-data').data('base-url');
        data = {};
        data[params.name] = params.value;
        return $.ajax("" + base_url + "/" + params.pk + ".json", {
          type: 'PUT',
          data: data
        });
      },
      error: function(response, newValue) {
        var msg;
        msg = response.responseJSON.error.str;
        switch (response.status) {
          case 404:
            msg = "\"" + params.value + "\" 태그를 찾을 수 없습니다.";
            break;
          case 400:
            if (msg === 'duplicate tag.name') {
              msg = "\"" + newValue + "\" 태그가 이미 존재합니다.";
            }
        }
        return msg;
      }
    };
    id = $(el).attr('id');
    if (0) {

    } else {
      params.type = 'text';
    }
    return $(el).editable(params);
  };
  return $('.editable').each(function(i, el) {
    return makeEditable(el);
  });
});
