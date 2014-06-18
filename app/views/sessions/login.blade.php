@extends('layouts.guest')

@section('content')

      <!-- /.login-wrapper -->
		
		<div class="login-wrapper">
			<div id="message">
                {{ Messages::show() }} 
            </div>
			
			{{ Form::open(array('route' => 'login', 'class' => 'register-form')) }}
				<div class="form-group has-feedback lg left-feedback no-label"> 
				  {{ Form::text(
                                        'email',
                                        '',
                                        array(
                                            'class' => 'form-control no-border input-lg rounded',
                                            'placeholder' => Lang::get('ui.email_p'),
                                            'title' => Lang::get('ui.email-title'),
                                            'autofocus'
                                            )
                                            ) }}	 
				  <span class="fa fa-user form-control-feedback"></span>
				</div>
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
				<div class="form-group">
				  <div class="checkbox">
				  	<label>{{ Form::checkbox('remember_me', null, false, array('class' => 'i-yellow-flat')) }} {{Lang::get('ui.remember_me')}}  </label>
				  </div>
				</div>
				<div class="form-group">
					{{ Form::submit(
                                    Lang::get('ui.login_btn'),
                                    array('class' => 'btn btn-warning btn-lg btn-perspective btn-block', 'name' => 'login-btn')) }}
				</div>
			 {{ Form::close() }}
			<p class="text-center"><strong>{{ link_to('/forgot', Lang::get('ui.forgot_pwd'), $attributes = array(), $secure = null) }}</strong></p>
			<!--<p class="text-center">or</p>
			<p class="text-center"><strong>{{ link_to('/register', Lang::get('ui.sign_up'), $attributes = array(), $secure = null) }}</strong></p>-->
		</div><!-- /.login-wrapper -->

@stop


