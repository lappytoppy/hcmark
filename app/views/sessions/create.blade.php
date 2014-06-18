@extends('layouts.guest')

@section('content')

      <!-- /.register-wrapper -->
		
<div class="login-wrapper">
    <div id="message">
        {{ Messages::show() }} 
    </div>
			
    {{ Form::open(array('url' => 'user', 'class' => 'form-horizontal')) }}

        <div class="form-group has-feedback lg left-feedback no-label">
          {{ Form::text(
                'full_name',
                null,
                array(
                    'class' => 'form-control no-border input-lg rounded',
                    'placeholder' => Lang::get('ui.full_name_p'),
                    'title' => Lang::get('ui.full_name_p'),
                    'autofocus'
                )
            ) 
          }}	
          <span class="fa fa-male form-control-feedback"></span>
        </div> 
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
        <div class="form-group has-feedback lg left-feedback no-label">
            {{ Form::password(
                'password',
                array(
                    'class' => 'form-control no-border input-lg rounded',
                    'placeholder' => Lang::get('ui.password_p'),
                    'title' => Lang::get('ui.password_p'),
                    'autofocus'
                    )
                ) 
            }}	
          <span class="fa fa-lock form-control-feedback"></span>
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
          <span class="fa fa-unlock form-control-feedback"></span>
        </div>
        <div class="form-group">
          <div class="checkbox"> 
                <label class="inline-popups">
                        <label>{{ Form::checkbox('terms_conditions', null, false, array('class' => 'i-yellow-flat')) }} {{Lang::get('ui.terms_accept')}} {{ link_to('#text-popup', Lang::get('ui.terms'), $attributes = array('data-effect' => 'mfp-zoom-in'), $secure = null) }}   </label>
                </label>
          </div>
        </div>
        <div class="form-group">
                {{ Form::submit(
                    Lang::get('ui.register'),
                    array('class' => 'btn btn-warning btn-lg btn-perspective btn-block', 'name' => 'login-btn')) }}
        </div>


    {{ Form::close() }}
</div><!-- /.register-wrapper -->

<!-- /. Term popup -->
<div id="text-popup" class="white-popup wide mfp-with-anim mfp-hide">
        <h4> {{ Lang::get('headings.terms') }}</h4>
        <p>
                {{ Lang::get('labels.term_detail') }}			 
        </p>

        <h4> {{ Lang::get('headings.conditions') }}</h4>

        <p>
                {{ Lang::get('labels.condition_detail') }}			 
        </p> 
</div>
<!-- /. Term popup -->

@stop


