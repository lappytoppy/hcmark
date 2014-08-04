<?php $assets = Config::get("assets"); ?>
@foreach($assets as $asset)
    @foreach($asset['request_match'] as $req)
        @if (Request::is($req) && $req != '*')
            @if (isset($asset['js']))
            @foreach($asset['js'] as $js)
                {{ HTML::script($js) }}
            @endforeach
            @endif
            @if (isset($asset['js-ifie']))
            <!--[if IE]>
                    @foreach($asset['js-ifie'] as $js)
            {{ HTML::script($js) }}
                    @endforeach
            <![endif]-->
            @endif
            <?php break; ?>
	@endif
    @endforeach
@endforeach

