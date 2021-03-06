$(document).ready(function () {
    var marker = window.btoa('0');
    var prefix = window.btoa(encodeURI($("body").data("prefix")));
    var all_loaded = false;
    var finished_loading = true;

    function load_more_entries() {
        if (!finished_loading) {
            return;
        }
        finished_loading = false;
        $('#loader').show();
        console.log("Updating entries", marker, prefix);
        $.get('/load/' + marker + '/' + prefix, function (data) {
            if (data) {
                $('#files').append(data);
                marker = $('#files tr:last td:first').html();
                console.log("New Marker: ", marker);
                marker = window.btoa(encodeURI(marker));
            } else {
                all_loaded = true;
                $('#nomore').fadeIn();
            }
            finished_loading = true;
            $('#loader').fadeOut();
        });
    }

    function reload() {
        $('#nomore').hide();
        $('#files').empty();
        all_loaded = false;
        marker = window.btoa('0');
        load_more_entries();
    }

    reload();

    $.get('/versioning', function (value) {
        if (value) {
            $('#versioning').append(value);
        }
    });

    $("#prefix").keyup($.debounce(500 ,function () {
        prefix = window.btoa(encodeURI($("body").data("prefix") + this.value));
        reload();
    }));


    $(document).on('click', '.openmodal', function () {
        var key = $(this).attr('key');
        console.info("clicked", key);
        $('#modal-content').empty();
        $('#modal-loader').show();
        $.ajax({
            url: `/${key}/versions`,
            success: function (data) {
                if (data) {
                    $('#modal-loader').fadeOut();
                    $('#modal-content').append(data);
                    $('.modal-title').html(decodeURI(window.atob(key)));
                }
            }
        });
    });

    $(window).scroll(function () {
        if (all_loaded || finished_loading == false)
            return;
        if ($(window).scrollTop() == $(document).height() - $(window).height()) {
                load_more_entries();
        }
    });

    $(document).on('change', "#select-bucket", function() {
        var bucket = $(this).val();
        console.info("change bucket", bucket)
        location = "/?bucket=" + encodeURI(bucket)
    });

    $(document).on('click', "#new-folder", function(e) {
        e.preventDefault();
        var dir = prompt("New folder name:")
        dir = dir.replace(/\//g, '')
        if(dir) {
            dir = "/d/" + $('body').data("prefix") + dir + '/';
            location = dir
        }
    });

    $(document).on('focus', "input.url", function() {
        $(this).select();
    });

    $(document).on('click', "button.copy", function() {
        var input =$(this).closest('form').find("input.url")[0];
        input.select();
        input.setSelectionRange(0, 99999); /*For mobile devices*/

        document.execCommand("copy");
        $(this).tooltip("show");
    });
});
