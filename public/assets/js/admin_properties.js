$(document).ready(function () {
    var usrCustomize1 = document.getElementById('usrCustomize').dataset.usrcustomize;
    var editUser1 = document.getElementById('editUser').dataset.edituser;
    var error1 = document.getElementById('error').dataset.error;
    var propstr1 = document.getElementById('propstr').dataset.propstr;
    var propForm1 = document.getElementById('propForm').dataset.propform;
    var msgs1 = document.getElementById('msgs').dataset.msgs;
    var propertiesListApi11 = $("span#proApi").data("proapi");
    var dtId = "#datatable-properties";
    var propList = jQuery(dtId).DataTable();
    var obj = JSON.parse(msgs1);
    function generateForm(_elem, _settings, _data, _lang, _edit) {
        return tmpl(_elem, {s: _settings, d: _data, l: _lang, e: _edit});
    }

    tt = null;

    function showStars(elem) {
        show = $('[value=' + $(elem).val() + ']', elem).data('show_stars');
        $rating = $('[name="star_rating_id"]', $(elem).closest('form'));
        $rFrm = $rating.closest('.form-group');

        if (show) {
            $rating.removeAttr('disabled').removeClass('disabled');
            $rFrm.slideDown();
        } else {
            $rating.attr('disabled', 'disabled').addClass('disabled');
            $rFrm.slideUp();
        }
    }

    function deleteProp(id) {
        err = msgs.gnrl;
        fUrl = propstr1;
        msgElem = '#message';
        $.ajax({
            type: "POST",
            url: fUrl,
            data: {id: id, _delete: 1},
            dataType: 'json',
            beforeSend: function () {
                spinner.hover(dtId);
            }
        })
            .error(function () {
                spinner.remove(dtId);
                __alert.error(msgElem);
                alert(err);
            })
            .success(function (data) {
                spinner.remove(dtId);
                if ('success' == data['type']) {
                    refreshPropList();
                }
                __alert.insert(msgElem, data['message'], data['type']);
            });
    }

    var nFst = propForm1;

    var refreshPropList = function () {
        var makeActionBtns = function (id) {
            return '<div data-id="' + id + '"><button class="btn btn-xs btn-info btn-edit prop-edit"><i class="fa fa-pencil"></i>Edit</button> <button class="btn btn-xs btn-danger btn-delete prop-delete"><i class="fa fa-trash-o"></i>Delete</button></div>';
        }
        $.ajax({
            type: "GET",
            url: lnk.epf,
            dataType: 'json',
            beforeSend: function () {
                spinner.hover(dtId);
            }
        })
            .error(function () {
                spinner.remove(dtId);
                alert(msgs.gnrl);
            })
            .success(function (data) {
                parsed = [];
                //Process Data and Create Action Buttons
                for (i in data) {
                    d = data[i];
                    parsed.push([d[0], d[1], d[2], d[3], makeActionBtns(d[4])]);
                }
                spinner.remove(dtId);
                propList.fnClearTable();
                propList.fnAddData(parsed);
            });
    }

    var arrCombine = function (keys, values) {
        var result = {};
        if ('object' != values) {
            values = JSON.parse(values);
        }
        for (i = 0; i < keys.length; i++) {
            result[keys[i]] = values[i] || '';
        }
        return result;
    }

    var msgss = {
        gnrl: obj.gnrl,
        npf: obj.npf,
        epf: obj.epf,
        ppn: obj.ppn, //templating automatically detects for variable with suffix _p as placeholder
        ppn_p: obj.ppn_p,
        fln: obj.fln,
        fln_p: obj.fln_p,
        ppt: obj.ppt,
        ppt_p: obj.ppt_p,
        tlp: obj.tlp,
        tlp_p: obj.tlp_p,
        eml: obj.eml,
        eml_p: obj.eml_p,
        nts: obj.nts,
        nts_p: obj.nts_p,
        str: obj.str,
        str_p: obj.str_p,
        str_d: obj.str_d,
        str_d: obj.str_d,
        pms_p: obj.pms_p,
        pmr: obj.pmr,
        pmr_p: obj.pmr_p,
        del_a: obj.del_a
    }

    var lnk = {
        epf: propertiesListApi11,
        cls: ['ppn', 'fln', 'eml', 'tlp', 'nts', 'id', 'ppt', 'str', 'pms', 'pmr']
    }
    jQuery(document).ready(function () {
        $('#uni-modal').on('submit', '#form-add-prop', function (e) {
            e.preventDefault();
            msgElem = '#uni-modal #form-add-prop .messages';
            mdlElem = '#uni-modal .modal-content';
            frmElem = '#uni-modal #form-add-prop';
            fUrl = $(this).attr('action');
            data = $(this).serialize();
            if (!fUrl) {
                __alert.error(msgElem);
                return false;
            }
            $.ajax({
                type: "POST",
                url: fUrl,
                data: data,
                dataType: 'json',
                beforeSend: function () {
                    spinner.hover(mdlElem);
                }
            })
                .error(function () {
                    spinner.remove(mdlElem);
                    __alert.error(msgElem);
                })
                .success(function (data) {
                    spinner.remove(mdlElem);
                    if ('success' == data['type']) {
                        clear = data['clear'] || false;
                        if (clear) {
                            $(frmElem).find('input,textarea').val(null);
                        }
                        refreshPropList();
                    }
                    __alert.insert(msgElem, data['message'], data['type']);
                });
        });

        /* =================================
         SHOW ADD MODAL
         =====================================*/
        $('#admin_prop_add').on('click', function () {
            modal.open(msgs.npf, false, generateForm('newPropForm', nFst, [], msgs));
        });

        /* =================================
         SHOW EDIT MODAL
         =====================================*/
        $('#datatable-properties').on('click', '.prop-edit', function () {
            id = $(this).parent().data('id');
            data = {id: id, _method: 'GET'};
            modal.open(msgs.epf, lnk.epf, data, function (_data) {
                /* args(Keys, Values) -> This merge the two arrays */
                data = arrCombine(lnk.cls, _data);
                return generateForm('newPropForm', nFst, data, msgs, id);
            });
        });

        /* =================================
         DELETE PROP
         =====================================*/
        $('#datatable-properties').on('click', '.prop-delete', function () {
            id = $(this).parent().data('id');
            bootbox.confirm(msgs.del_a, function (result) {
                if (result) {
                    deleteProp(id);
                }
            });
        });

        refreshPropList();
    });
});