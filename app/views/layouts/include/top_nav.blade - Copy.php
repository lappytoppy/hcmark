<?php
try
{
    $group = Sentry::getUser()->groups->first()->name;
}
catch (Cartalyst\Sentry\Users\UserNotFoundException $e)
{
    echo 'User was not found.';
}

$links = Config::get("template.user_menu_links.$group");

?>
            <!-- BEGIN TOP NAV -->
            <div class="top-navbar">
                <div class="top-navbar-inner">
                    
                    <!-- Begin Logo brand -->
                    <div class="logo-brand">
                        <a href="#"><img src="/assets/img/sentir-logo-primary.png" alt="Logo"></a>
                    </div><!-- /.logo-brand -->
                    <!-- End Logo brand -->
                    
                    <div class="top-nav-content">
                        <ul class="nav-user navbar-right">
                            <li class="dropdown">
                              <a href="#" class="dropdown-toggle" data-toggle="dropdown">
                                <img src="/assets/img/avatar/avatar.jpg" class="avatar img-circle" alt="Avatar">
                                {{ Lang::get('ui.hi') }} <strong>{{ ucfirst(Sentry::getUser()->full_name) }}</strong>
                              </a>
                              <ul class="dropdown-menu square primary margin-list-rounded with-triangle"> 
                                @foreach($links as $link)
                                <li>
                                    @if (isset($link['divider']))
                                    <li class="divider"></li>
                                    @else
                                    <a id="{{ $link['id'] }}" href="{{ route($link['route']) }}">{{ Lang::get($link['lang']) }}</a>
                                    @endif
                                </li>
                                @endforeach
                              </ul>
                            </li>
                        </ul>
                        <!-- End user session nav -->
                        
                        <!-- Begin Collapse menu nav -->
                        <div class="collapse navbar-collapse" id="main-fixed-nav">
                        </div><!-- /.navbar-collapse -->
                        <!-- End Collapse menu nav -->
                    </div><!-- /.top-nav-content -->
                </div><!-- /.top-navbar-inner -->
            </div><!-- /.top-navbar -->
            <!-- END TOP NAV -->