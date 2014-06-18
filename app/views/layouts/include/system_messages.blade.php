@if (Session::has('admin_id'))
<?php
$cur_group = '';
$user = Sentry::getUser();
$admin = Sentry::findGroupByName('admin');

if ($user->inGroup($admin))
{
    $cur_group = 'admin';
}
else
{
    $cur_group = 'user';
}
?>
<div class="system-messages">
    <center>
    {{ Lang::get('system.loggin_as')}} {{ ucfirst(Sentry::getUser()->full_name) }} ({{ Lang::get('system.' . $cur_group) }}). Go back to <a href="{{ route('logout') }}">{{ Lang::get('system.admin') }}</a>
    </center>
</div>
<script>
    (function(){
        sm = document.getElementsByClassName("system-messages")[0];
        st = document.createElement("style");
        smh = sm.clientHeight;
        st.innerHTML = '.top-navbar{top:' + smh + 'px}.page-content{margin-top:' + smh + 'px}.sidebar-left{margin-top:' + smh + 'px}';
        sm.appendChild(st);
    })()
</script>
@endif