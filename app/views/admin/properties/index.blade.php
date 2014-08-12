@extends('layouts.admin')

@section('content')

<span data-usrCustomize="<?php echo $meta['usrCustomize']; ?>" id="usrCustomize">
    <span data-editUser="<?php echo $meta['editUser']; ?>" id="editUser">
    <span data-error="<?php echo $meta['error']; ?>" id="error">
    <span data-propstr="<?php echo $meta['propstr']; ?>" id="propstr">




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
//$jse=json_encode($meta);
//echo $jse;

?>


    <span data-user_update=<?php echo $meta['user_update']; ?> id="user_update">
    <span data-propForm=<?php echo "'" . json_encode($propForm) . "'"; ?> id="propForm">
    <span data-msgs=<?php echo "'" . json_encode($meta) . "'"; ?> id="msgs">
    <span data-proApi="<?php echo $meta['propertiesListApi']; ?>" id="proApi">
    <span data-spinner="<?php echo $meta['spinner']; ?>" id="spinner">
        <span data-account_edit="<?php echo $meta['account_edit']; ?>" id="account_edit">


        @stop

@section('inline_scripts')
@include('admin.properties.new_property_template')
@stop