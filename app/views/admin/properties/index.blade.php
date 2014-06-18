@extends('layouts.admin')

@section('content')

<div class="container-fluid">

<!-- Begin page heading -->
<h1 class="page-heading">{{ Lang::get('headings.properties') }}</h1>
<!-- End page heading -->

<div id="message">
{{ Messages::show() }} 
</div>

<div class="the-box">
    <h4 class="small-title"> 
        <a id="admin_prop_add" class="btn btn-primary"><i class="fa fa-plus"></i>{{ Lang::get('ui.add_property') }}</a>
    </h4> 
    <div class="table-responsive">
    <table class="table table-striped table-hover" id="datatable-properties" style="position:relative">
            <thead class="the-box dark full">
                <tr>
                    <th>{{ Lang::get('headings.property_name') }}</th>
                    <th>{{ Lang::get('headings.full_name') }}</th>
                    <th>{{ Lang::get('headings.email') }}</th>
                    <th>{{ Lang::get('headings.telephone') }}</th>
                    <th>{{ Lang::get('headings.action') }}</th>
                </tr>
            </thead>
            <tbody>
            </tbody>
    </table>
    </div>
</div>

@stop

@section('inline_scripts')
@include('admin.properties.new_property_template')


<?php

/*==========================
 *    form data structure
 ==========================*/

$propForm = array(
    array(
        'col-md-6',
        'groups' => array(
            'ppn' => array(
                '_input'  => true,
                'label'   => 'ppn', /* just a language handler on js */
                'attr'    => array(
                    'name'        => 'property_name',
                    'class'       => 'form-control',
                    'required'    => 'required'
                )
            ),
            'ppt' => array(
                '_select'   => true,
                'label'     => 'ppt',
                'default'   => 'disabled',
                'options'   => $property_types,
                'isObject'  => true,
                'labelKey'  => 'name',
                /* include other data on object to attributes
                 * this will result to data-show_stars="1" or data-show_stars="0" */
                'inclData'  => array('show_stars'),
                'attr'    => array(
                    'name'        => 'property_type_id',
                    'id'          => 'property_type_id',
                    'class'       => 'form-control',
                    'required'    => 'required',
                    'onchange'    => "showStars(this)"
                )
            ),
            'str' => array(
                '_select'   => true,
                'label'     => 'str',
                'options'   => $star_ratings,
                'default'   => '0',
                /* Tells whether a certain input group is visible or not
                 * model => tells whether or not this input will be visible
                 * elemdata => will tell what is the current value selected on the condition
                 *  */
                'visible'   => array('model'  => '0.groups.ppt.options.%d.show_stars',
                                     'data'   => 'ppt.0'),
                'attr'    => array(
                    'name'        => 'star_rating_id',
                    'class'       => 'form-control'
                )
            ),
            'fln' => array(
                '_input'  => true,
                'label'   => 'fln',
                'attr'    => array(
                    'name'        => 'full_name',
                    'class'       => 'form-control',
                    'required'    => 'required'
                )
            ),
            'tlp' => array(
                '_input'  => true,
                'label'   => 'tlp',
                'attr'    => array(
                    'name'        => 'telephone',
                    'class'       => 'form-control',
                    'required'    => 'required'
                )
            ),
        )
    ),
    array(
        'col-md-6',
        'groups' => array(
            'eml' => array(
                '_input'  => true,
                'label'   => 'eml',
                'attr'    => array(
                    'name'        => 'email',
                    'class'       => 'form-control',
                    'required'    => 'required'
                )
            ),
            'pms' => array(
                '_select'   => true,
                'label'     => 'pms',
                'options'   => $pms_configs,
                'default'   => '0',
                'attr'    => array(
                    'name'        => 'pms_config_id',
                    'class'       => 'form-control'
                )
            ),
            'pmr' => array(
                '_input'  => true,
                'label'   => 'pmr',
                'attr'    => array(
                    'name'        => 'pms_account_ref',
                    'class'       => 'form-control'
                )
            ),
            'nts' => array(
                '_textarea'  => true,
                'label'   => 'nts',
                'attr'    => array(
                    'name'        => 'notes',
                    'class'       => 'form-control',
                    'style'       => 'min-height:109px'
                )
            )
        )
    )
);

?>
<script>
var dtId = "#datatable-properties";
var propList = jQuery(dtId).DataTable();

function generateForm(_elem, _settings, _data, _lang, _edit){
    return tmpl(_elem, {s:_settings,d:_data,l:_lang,e:_edit});
}

tt = null;

function showStars(elem){
    show = $('[value=' + $(elem).val() + ']', elem).data('show_stars');
    $rating = $('[name="star_rating_id"]', $(elem).closest('form'));
    $rFrm = $rating.closest('.form-group');
    
    if (show){
        $rating.removeAttr('disabled').removeClass('disabled');
        $rFrm.slideDown();
    } else {
        $rating.attr('disabled','disabled').addClass('disabled');
        $rFrm.slideUp();
    }
}

function deleteProp(id){
    err  = msgs.gnrl;
    fUrl  = '{{ route("admin.propstr") }}';
    msgElem = '#message';
    $.ajax({
        type: "POST",
        url: fUrl,
        data: {id:id,_delete:1},
        dataType: 'json',
        beforeSend: function(){
            spinner.hover(dtId);
        }
    })
    .error(function(){
        spinner.remove(dtId);
        __alert.error(msgElem);
        alert(err);
    })
    .success(function(data) {
        spinner.remove(dtId);
        if ('success' == data['type']){
            refreshPropList();
        }
        __alert.insert(msgElem, data['message'], data['type']);
    });
}

var nFst = {{ json_encode($propForm) }};
    
var refreshPropList = function(){
    var makeActionBtns = function(id){
        return '<div data-id="'+id+'"><button class="btn btn-xs btn-info btn-edit prop-edit"><i class="fa fa-pencil"></i>Edit</button> <button class="btn btn-xs btn-danger btn-delete prop-delete"><i class="fa fa-trash-o"></i>Delete</button></div>';
    }
    $.ajax({
        type: "GET",
        url: lnk.epf,
        dataType: 'json',
        beforeSend: function(){
            spinner.hover(dtId);
        }
    })
    .error(function(){
        spinner.remove(dtId);
        alert(msgs.gnrl);
    })
    .success(function(data) {
        parsed = [];
        <?php /* Process Data and Create Action Buttons */ ?>
        for (i in data){
            d = data[i];
            parsed.push([d[0],d[1],d[2],d[3],makeActionBtns(d[4])]);
        }
        spinner.remove(dtId);
        propList.fnClearTable();
        propList.fnAddData(parsed);
    });
}

var arrCombine = function(keys, values){
    var result = {};
    if ('object' != values){
        values = JSON.parse(values);
    }
    for (i = 0; i < keys.length; i++){
        result[keys[i]] = values[i] || '';
    }
    return result;
}

var msgs = {
    gnrl : '{{ Lang::get("messages.general") }}',
    npf  : '{{ Lang::get("ui.add_property") }}',
    epf  : '{{ Lang::get("ui.edit_property") }}',
    ppn  : '{{ Lang::get("ui.property_name") }}', <?php /* templating automatically detects for variable with suffix _p as placeholder*/ ?>
    ppn_p: '{{ Lang::get("ui.property_name_p") }}',
    fln  : '{{ Lang::get("ui.full_name") }}',
    fln_p: '{{ Lang::get("ui.full_name_p") }}',
    ppt  : '{{ Lang::get("ui.property_type") }}',
    ppt_p: '{{ Lang::get("ui.property_type_p") }}',
    tlp  : '{{ Lang::get("labels.telephone") }}',
    tlp_p: '{{ Lang::get("labels.telephone_p") }}',
    eml  : '{{ Lang::get("ui.email_add") }}',
    eml_p: '{{ Lang::get("ui.email_p") }}',
    nts  : '{{ Lang::get("labels.notes") }}',
    nts_p: '{{ Lang::get("labels.notes_p") }}',
    str  : '{{ Lang::get("ui.star_rating") }}',
    str_p: '{{ Lang::get("ui.star_rating_p") }}',
    str_d: '{{ Lang::get("ui.star_rating_d") }}',
    pms  : '{{ Lang::get("ui.pms_config") }}',
    pms_p: '{{ Lang::get("ui.pms_config_p") }}',
    pmr  : '{{ Lang::get("ui.pms_acc_ref") }}',
    pmr_p: '{{ Lang::get("ui.pms_acc_ref_p") }}',
    del_a: '{{ Lang::get("ui.confirm_delete") }}'
}

var lnk = {
    epf : '{{ route("admin.propertiesListApi") }}',
    cls : ['ppn','fln','eml','tlp','nts','id','ppt','str','pms','pmr']
}

jQuery(document).ready(function(){
    $('#uni-modal').on('submit', '#form-add-prop', function(e){
        e.preventDefault();
        msgElem = '#uni-modal #form-add-prop .messages';
        mdlElem = '#uni-modal .modal-content';
        frmElem = '#uni-modal #form-add-prop';
        fUrl = $(this).attr('action');
        data = $(this).serialize();
        if (!fUrl)
        {
            __alert.error(msgElem);
            return false;
        }
        $.ajax({
            type:"POST",
            url:fUrl,
            data:data,
            dataType:'json',
            beforeSend: function(){
                spinner.hover(mdlElem);
            }
        })
        .error(function(){
            spinner.remove(mdlElem);
            __alert.error(msgElem);
        })
        .success(function(data){
            spinner.remove(mdlElem);
            if ('success' == data['type']){
                clear = data['clear'] || false;
                if (clear){
                    $(frmElem).find('input,textarea').val(null);
                }
                refreshPropList();
            }
            __alert.insert(msgElem, data['message'], data['type']);
        });
    });
    
    <?php /* =================================
                SHOW ADD MODAL
    =====================================*/ ?>
    $('#admin_prop_add').on('click', function(){
        modal.open(msgs.npf, false, generateForm('newPropForm',nFst,[],msgs));
    });
    
    <?php /* =================================
                SHOW EDIT MODAL
    =====================================*/ ?>
    $('#datatable-properties').on('click', '.prop-edit', function(){
        id = $(this).parent().data('id');
        data = {id:id,_method:'GET'};
        modal.open(msgs.epf, lnk.epf, data,function(_data){
            <?php /* args(Keys, Values) -> This merge the two arrays */ ?>
            data = arrCombine(lnk.cls,_data);
            return generateForm('newPropForm',nFst,data,msgs,id);
        });
    });
    
    <?php /* =================================
                DELETE PROP
    =====================================*/ ?>
    $('#datatable-properties').on('click', '.prop-delete', function(){
        id = $(this).parent().data('id');
        bootbox.confirm(msgs.del_a, function(result) {
          if (result)
          {
              deleteProp(id);
          }
        }); 
    });
    
    refreshPropList();
});
</script> 
@stop