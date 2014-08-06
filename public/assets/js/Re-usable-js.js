var usrCustomize1 = document.getElementById('usrCustomize').dataset.usrcustomize;
var editUser1 = document.getElementById('editUser').dataset.edituser;
var error1 = document.getElementById('error').dataset.error;
var user_update1 = document.getElementById('user_update').dataset.user_update;
var spinner1 = document.getElementById('spinner').dataset.spinner;
var account_edit1 = document.getElementById('account_edit').dataset;


var urls = {
        'usrCustomize': usrCustomize1,
        'editUser': editUser1
    },
    messages = {
        'error': error1
    },
    __alert = {
        'insert': function (_element, _message, _class) {
            if ('string' == typeof _class) {
                _class = ['alert-' + _class];
            }
            jQuery(_element).html(this.createTags(_message, _class));
        },
        'error': function (_element, _message) {
            if ('undefined' == typeof _message) {
                _message = messages.error;
            }
            jQuery(_element).html(this.createTags(_message, ['alert-danger']));
        },
        'createTags': function (_content, _class) {
            h = jQuery('<div />');
            b = jQuery('<button />');
            ba = {'aria-hidden': 'true', 'data-dismiss': 'alert', 'class': 'close', 'type': 'button'};
            bc = '&times;';
            hc = ['alert', 'alert-bold-border', 'fade', 'in', 'alert-dismissable'];
            if ('object' == typeof _class) {
                hc = hc.concat(_class);
            }
            h.addClass(hc.join(' '));
            b.attr(ba);
            b.html(bc);
            h.text(_content);
            h.prepend(b);

            return h;
        }
    },
    spinner = {
        'hover': function (element) {
            jQuery(element).prepend(jQuery('<div class="spinner-hover" style="position: absolute;z-index: 1024;width: 100%;height: 100%;display: block;background-color: #FFF;background-image: url(' + spinner1 + ');background-repeat: no-repeat;background-position: center;opacity: 0.4;"></div>'));
        },
        'remove': function (element) {
            jQuery(element).find('.spinner-hover').fadeOut().remove();
        }
    },
    modal = {
        'open': function (header, url, data, callback) {
            var $h = jQuery(jQuery($('#uni-modal-handler').html())),
                $m = jQuery('#uni-modal');
            mtd = data['_method'] || 'POST';
            if (header) {
                $h.find('.modal-title').text(header);
                $m.find('.modal-dialog').html($h);
            }
            $m.modal('show');
            if (url) {
                jQuery.ajax({
                    type: mtd,
                    url: url,
                    data: data
                })
                    .fail(function () {
                        var error = error1;
                        $m.find('.modal-body').text(error);
                    })
                    .success(function (rcv) {
                        var content = '';
                        if ('function' == typeof callback) {
                            content = callback(rcv);
                        } else {
                            content = rcv;
                        }
                        $m.find('.modal-body').html(content);
                    });
            } else {
                $m.find('.modal-body').html(data);
            }
        },
        'spin': function () {
            spinner.hover('#uni-modal .modal-content');
        },
        'unspin': function () {
            spinner.remove('#uni-modal .modal-content');
        },
        'error': function () {
            modal.open(false, false, error1);
        }
    },
    _confirm = function (msg, func) {
        __confirm.show(mgs, elem, data);
    }

jQuery().ready(function () {
    jQuery('body').on('click', 'confirm-btn', function (e) {
        e.preventDefault();
    });
    jQuery('#global-user-edit').on('click', function (e) {
        e.preventDefault();
        $ch = jQuery('#edit-modal-handler').html();
        jQuery('#global-edit-account > .modal-dialog').html($ch);
        jQuery('#global-edit-account').modal('show');
        $.ajax({
            type: "GET",
            url: account_edit1
        })
            .success(function (data) {
                jQuery('#global-edit-account > .modal-dialog').html(data);
            });
    });
    jQuery('#global-edit-account').on('submit', '#global-edit-form', function (e) {
        e.preventDefault();
        $frm = jQuery(this).closest('form');
        $.ajax({
            type: "POST",
            data: $frm.serialize(),
            url: "user_update1"
        })
            .success(function (data) {
                $ch = jQuery('#edit-modal-handler').html();
                jQuery('#global-edit-account > .modal-dialog').html($ch);
                jQuery('#global-edit-account').modal('show');
                $.ajax({
                    type: "GET",
                    url: account_edit1
                })
                    .success(function (data) {
                        jQuery('#global-edit-account > .modal-dialog').html(data);
                    });
            });
    })
})
