@extends('layouts.guest')

@section('content')

      <!-- /.forgot-password-wrapper -->
       
        <div class="login-wrapper">
            <div id="message">
                {{ Messages::show() }} 
            </div>
            
            {{ Form::open(array('route' => 'forgot_send', 'class' => 'register-form')) }}


                 
                <div class="form-group has-feedback lg left-feedback no-label">
                   {{ Form::text(
                                'email',
                                null,
                                array(
                                    'class' => 'form-control no-border input-lg rounded',
                                    'placeholder' => Lang::get('ui.email_p'),
                                    'title' => Lang::get('ui.email_p'),
                                    'autofocus'
                                    )
                                ) 
                    }}  
                  <span class="fa fa-envelope form-control-feedback"></span>
                </div> 
                <div class="form-group">
                    {{ Form::submit(
                                    Lang::get('ui.reset_pwd'),
                                    array('class' => 'btn btn-warning btn-lg btn-perspective btn-block', 'name' => 'login-btn')) }}
                </div>              
             
             {{ Form::close() }}
             <p class="text-center"><strong><a href="login.html">{{ link_to('/', Lang::get('ui.back_login'), $attributes = array('data-effect' => 'mfp-zoom-in'), $secure = null) }}</a></strong></p>

        </div><!-- /.forgot-password-wrapper --> 

@stop


