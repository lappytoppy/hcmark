@extends('layouts.guest')

@section('content')
       <!-- /.reset-wrapper -->
            <div class="login-wrapper">
            <div id="message">
                {{ Messages::show() }} 
            </div>
            @if($salt)
                {{ Form::open(array('url' => 'reset_save', 'class' => 'form-horizontal')) }}

                    {{ Form::hidden('code', $user_info['code']) }}	
                    {{ Form::hidden('email', $user_info['email']) }}	
                    <div class="form-group has-feedback lg left-feedback no-label">
                        {{ Form::password(
                            'password',
                            array(
                                'class' => 'form-control no-border input-lg rounded',
                                'placeholder' => Lang::get('ui.password_p'),
                                'title' => Lang::get('ui.password_title'),
                                'autofocus'
                                )
                            ) }}	 
                      <span class="fa fa-unlock-alt form-control-feedback"></span>
                    </div>

                    <div class="form-group has-feedback lg left-feedback no-label">
                       {{ Form::password(
                            'password_confirmation',
                            array(
                                'class' => 'form-control no-border input-lg rounded',
                                'placeholder' => Lang::get('ui.repassword_p'),
                                'title' => Lang::get('ui.repassword_p'),
                                'autofocus'
                                )
                            ) 
                 }}	 
                      <span class="fa fa-unlock-alt form-control-feedback"></span>
                    </div>


                    <div class="form-group">
                            {{ Form::submit(
                                Lang::get('ui.change_password'),
                                array('class' => 'btn btn-warning btn-lg btn-perspective btn-block', 'name' => 'login-btn')) }}
                    </div>
             {{ Form::close() }}
            @else 
                <div >
                   {{  Lang::get('messages.invalid_url') }} 
               </div>
            @endif
        </div>
		<!-- /.reset-wrapper --> 
@stop 