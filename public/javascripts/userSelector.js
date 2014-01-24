$(function(){
    // Autocomplete
    $(".user-multi-select").each(function(){
        var ums = $(this);
        var userAutocomplete = ums.find("input.new-user").autocomplete({
            serviceUrl:'/users/search.json',
            minChars: 3,
            maxHeight: 400,
            width: 350,
            onSelect: function(value, data){
                var new_user_input = ums.find('.new-user');
                new_user_input.val('');
                ums.find('.user-list').append('<div><input type="hidden" name="' + ums.data("field-name") + '[]" value="' + data['_id'] +'"> <span class="span3 uneditable-input">' + data['firstname'] + " " + data['lastname'] + '</span> <a href="#remove" style="color: inherit;" class="remove"><i class="icon-remove"></i></a></div>');
                var limit = ums.data('user-limit');
                if (limit > 0) {
                    var value_count = ums.find("input:hidden").length - 1;
                    if (value_count >= limit) {
                        new_user_input.val('Maximum Limit Reached.');
                        new_user_input.prop( "disabled", true);
                    }
                }
            }
        });

        // Ensures that empty lists are passed as empty instead of not being updated.
        ums.prepend('<input type="hidden" name="' + ums.data("field-name") + '[]" value="" />');

        // Make sure that limits are enforced, even on pageload
        var new_user_input = ums.find('.new-user');
        var limit = ums.data('user-limit');
        if (limit > 0) {
            var value_count = ums.find("input:hidden").length - 1;
            if (value_count >= limit) {
                new_user_input.val('Maximum Limit Reached.');
                new_user_input.prop( "disabled", true);
            }
        }        
   });

    $(".user-multi-select").delegate("a.remove", "click", function() {
        var link = $(this);
        var ums = link.parent().parent().parent().parent();
        
        link.parent().remove();

        var limit = ums.data('user-limit');

        if (limit > 0) {
            var value_count = ums.find("input:hidden").length - 1;
            var new_user_input = ums.find('.new-user');

            if (limit > value_count && new_user_input.prop('disabled')) {
                new_user_input.val('');
                new_user_input.prop('disabled', false);
            }
        }
        return false;
    });
});

