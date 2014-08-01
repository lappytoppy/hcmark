@extends('layouts.admin')

@section('content')
<span data-usrCustomize="<?php echo $meta['usrCustomize']; ?>" id="usrCustomize">
<span data-editUser="<?php echo $meta['editUser']; ?>" id="editUser">
    <span data-error="<?php echo $meta['error']; ?>" id="error">

<div class="container-fluid">

    <!-- Begin page heading -->
    <h1 class="page-heading">{{ Lang::get('headings.manage_user') }}</h1>
    <!-- End page heading -->

    <div id="message">
        {{ Messages::show() }}
    </div>

    <!-- BEGIN DATA TABLE -->
    <div class="the-box">
        <h4 class="small-title inline-popups ">
            <a id="add-user-button" data-target="#admin_user_add" data-toggle="modal" class="btn btn-primary"><i
                    class="fa fa-plus"></i>{{ Lang::get('ui.add_user') }}</a>
        </h4>

        <div class="table-responsive">
            <table class="table table-striped table-hover" id="datatable-user">
                <thead class="the-box dark full">
                <tr>
                    <th>{{ Lang::get('headings.full_name') }}</th>
                    <th>{{ Lang::get('headings.email') }}</th>
                    <th>{{ Lang::get('headings.role') }}</th>
                    <th>{{ Lang::get('headings.status') }}</th>
                    <th>{{ Lang::get('headings.action') }}</th>
                </tr>
                </thead>
                <tbody>
                </tbody>
            </table>
        </div>
        <!-- /.table-responsive -->
    </div>
    <!-- /.the-box .default -->
    <!-- END DATA TABLE -->

</div><!-- /.container-fluid -->


<!-- Form popup -->


<div id="edit-user-pre-content" style="position:fixed;display:none !important;width:0;height:0;font-size:0">
    <div class="modal-content">
        <div class="modal-header">
            <button aria-hidden="true" data-dismiss="modal" class="close" type="button">×</button>
            <h4 class="modal-title">{{ Lang::get('headings.edit_user') }}</h4>
        </div>
        <div class="modal-body">
            <center style="width:100%;height:100%"><img src="/assets/img/ajax-loader.gif"/></center>
        </div>
    </div>
</div>

@include('admin.users.new_user_template')

<style>
    #form_user_add label.checkbox {
        padding-top: 0;
        min-height: 20px;
    }

    .action .btn {
        font-size: 10px;
        padding: 3px 4px 3px 2px;
    }
</style>
@stop

@section('inline_scripts')

@stop

