@extends('layouts.default')


@section('content')

<?php
Form::macro('static_input', function($name)
{
    $value = Form::getValueAttribute($name);
    return '<p class="form-control-static">' . $value . '</p>';
});
?>

<!-- /.register-wrapper -->
<div class="container-fluid">
    <!-- Begin page heading -->
    <h1 class="page-heading">{{ Lang::get('headings.account') }} <small>{{ Lang::get('headings.sub_account') }}</small></h1>
    <!-- End page heading -->

    <!-- Begin breadcrumb -->
    <ol class="breadcrumb default square rsaquo sm">
            <li><a href="/"><i class="fa fa-home"></i></a></li>
            <li><a href="/dashboard">{{ Lang::get('breadcrumb.dashboard') }}</a></li>
            <li class="active">{{ Lang::get('breadcrumb.account') }}</li>
    </ol>
    <!-- End breadcrumb --> 
    <div class="row"> 
        <div class="col-sm-12">
            <div class="the-box">
                <h4 class="small-title">{{ Lang::get('headings.account_detail') }}</h4>
                <div id="message">
                    {{ Messages::show() }} 
                </div>
                {{ Form::model($user, array('method' => 'put', 'route' => array('user.update', $user->id), 'role' => 'form')) }}
                {{ Form::hidden ('email') }}
                {{ Form::hidden ('notes') }}  
                <div class="row"> 
                    <div class="col-sm-6">
                        <div class="form-group">
                            <label>{{ Lang::get('ui.email_add') }}</label>
                            {{ Form::static_input('email') }} 
                        </div>
                        <div class="form-group">
                              <label>{{ Lang::get('ui.password') }}</label>
                              {{ Form::password(
                                  'password',
                                  array(
                                      'class' => 'form-control',
                                      'placeholder' => Lang::get('ui.password_p'),
                                      'title' => Lang::get('ui.password_p'),
                                      'autofocus'
                                      )
                                  ) 
                              }}	
                        </div>
                        <div class="form-group">
                              <label>{{ Lang::get('ui.re_password') }}</label>
                              {{ Form::password(
                                      'password_confirmation',
                                      array(
                                          'class' => 'form-control',
                                          'placeholder' => Lang::get('ui.repassword_p'),
                                          'title' => Lang::get('ui.repassword_p'),
                                          'autofocus'
                                          )
                                      ) 
                              }}	
                        </div>
                 </div>
                 <div class="col-md-6">
                        <div class="form-group">
                              <label>{{ Lang::get('ui.full_name_p') }}</label>
                              {{ Form::text(
                                  'full_name',
                                  null,
                                  array(
                                      'class' => 'form-control',
                                      'placeholder' => Lang::get('ui.full_name_p'),
                                      'title' => Lang::get('ui.full_name_p'),
                                      'autofocus'
                                      )
                                  ) 
                              }}    
                        </div>
                        <div class="form-group">
                               <label>{{ Lang::get('labels.org_name') }}</label>
                                {{ Form::text(
                                    'org_name',
                                    null,
                                    array(
                                        'class' => 'form-control',
                                        'id' => 'org_name',
                                        'placeholder' => Lang::get('labels.org_name_p'),
                                        'title' => Lang::get('labels.org_name_p'),
                                        'autofocus'
                                        )
                                    ) 
                                }}  
                        </div>
                        <div class="form-group">
                               <label>{{ Lang::get('labels.telephone') }}</label>
                                {{ Form::text(
                                    'telephone',
                                    null,
                                    array(
                                        'class' => 'form-control',
                                        'id' => 'telephone',
                                        'placeholder' => Lang::get('labels.telephone_p'),
                                        'title' => Lang::get('labels.telephone_p'),
                                        'autofocus'
                                        )
                                    ) 
                                }}  
                        </div>
                    </div>
                </div>
                <button class="btn btn-primary" type="submit">{{ Lang::get('ui.update') }}</button>
                {{ Form::close() }}
            </div><!-- /.the-box --> 
        </div><!-- /.col-sm-6 -->
    </div><!-- /.row --> 
</div>	 
@stop


