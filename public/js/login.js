$(function() {
  return Window.prototype.show_box = function(id) {
    $('.widget-box.visible').removeClass('visible');
    return $("#" + id).addClass('visible');
  };
});
