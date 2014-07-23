<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <title>{{ (isset($meta['title']) ? $meta['title'] : 'HPD') }} </title>
        
        <?php $assets = Config::get("assets"); ?>

        @foreach($assets as $asset)
            @foreach($asset['request_match'] as $req)
                @if (Request::is($req) && $req != '*')
                    @if (isset($asset['css']))
		    @foreach($asset['css'] as $css)
                        {{ HTML::style($css) }}
                    @endforeach
                    @endif
                    @if (isset($asset['css-ifie']))
                    <!--[if IE]>
                        @foreach($asset['css-ifie'] as $css)
                        {{ HTML::script($css) }}
                        @endforeach
                    <![endif]-->
                    @endif
                    <?php break; ?>
                @endif
            @endforeach
        @endforeach
    </head>
