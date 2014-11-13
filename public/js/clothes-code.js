$(function() {
  $('.order-status').each(function(i, el) {
    $(el).addClass(OpenCloset.status[$(el).data('status')].css);
    if ($(el).data('late-fee') > 0) {
      return $(el).find('.order-status-str').html('연체중');
    }
  });
  $('.clothes-code').each(function(i, el) {
    return $(el).html(OpenCloset.trimClothesCode($(el).html()));
  });
  $(".chosen-select").chosen({
    width: '90%'
  }).change(function() {
    var base_url, clothes_code, tag_list;
    tag_list = $(this).val();
    clothes_code = $(this).data('clothes-code');
    base_url = $(this).data('base-url');
    return $.ajax("" + base_url + "/clothes/" + clothes_code + "/tag.json", {
      type: 'PUT',
      data: $.param({
        tag_id: tag_list
      }, 1)
    });
  });
  return $('.editable').each(function(i, el) {
    var color, color_str, k, params, v, _ref;
    params = {
      mode: 'inline',
      showbuttons: 'true',
      emptytext: '비어있음',
      pk: $('#profile-clothes-info-data').data('pk'),
      url: function(params) {
        var data, url;
        url = $('#profile-clothes-info-data').data('url');
        data = {};
        data[params.name] = params.value;
        return $.ajax(url, {
          type: 'PUT',
          data: data
        });
      }
    };
    switch ($(el).attr('id')) {
      case 'clothes-category':
        params.type = 'select';
        params.source = (function() {
          var _ref, _results;
          _ref = OpenCloset.category;
          _results = [];
          for (k in _ref) {
            v = _ref[k];
            _results.push({
              value: k,
              text: v.str
            });
          }
          return _results;
        })();
        params.display = function(value) {
          return $(this).html(OpenCloset.category[value].str);
        };
        break;
      case 'clothes-gender':
        params.type = 'select';
        params.source = [
          {
            value: 'male',
            text: "남성용"
          }, {
            value: 'female',
            text: "여성용"
          }, {
            value: 'unisex',
            text: "남녀공용"
          }
        ];
        params.display = function(value) {
          var value_str;
          switch (value) {
            case 'male':
              value_str = '남성용';
              break;
            case 'female':
              value_str = '여성용';
              break;
            case 'unisex':
              value_str = '남녀공용';
              break;
            default:
              value_str = '';
          }
          return $(this).html(value_str);
        };
        break;
      case 'clothes-color':
        params.type = 'select';
        params.source = [];
        _ref = OpenCloset.color;
        for (color in _ref) {
          color_str = _ref[color];
          params.source.push({
            value: color,
            text: color_str
          });
        }
        break;
      default:
        params.type = 'text';
    }
    return $(el).editable(params);
  });
});
