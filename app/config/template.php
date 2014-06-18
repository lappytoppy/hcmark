<?php

return array(

	'sidebar_link' => array(
		
		'admin' => array(
			array(
				'route'     => 'admin.dashboard',
				'lang'      => 'links.dashboard',
				'class'     => 'fa fa-dashboard icon-sidebar',
				'id'        => '',
				'child'     => array()
			),
			array(
				'route'     => 'admin.users',
				'lang'      => 'links.users',
				'class'     => 'fa fa-user icon-sidebar',
				'id'        => '',
				'child'     => array()
			),
			array(
                'route'     => 'admin.properties',
                'lang'      => 'links.properties',
                'class'     => 'fa fa-home icon-sidebar',
                'id'        => '',
                'child'     => array()
            )
		),
		
		'user' => array(
			array(
				'route'     => 'dashboard',
				'lang'      => 'links.dashboard',
				'class'     => 'fa fa-dashboard icon-sidebar',
				'id'        => '',
				'child'     => array()
			)
		)
		
	),
	
    'user_menu_links' => array(
        'admin' => array(
            array(
                'route'     => 'account',
                'lang'      => 'nav.account',
                'class'     => '',
                'id'        => 'global-user-edit',
                'child'     => array()
            ),
            array(
                'divider'   => ''
            ),
            array(
                'route'     => 'logout',
                'lang'      => 'nav.logout',
                'class'     => '',
                'id'        => '',
                'child'     => array()
            )
        ),
        
        'user' => array(
            array(
                'route'     => 'account',
                'lang'      => 'nav.account',
                'class'     => '',
                'id'        => 'global-user-edit',
                'child'     => array()
            ),
            array(
                'divider'   => ''
            ),
            array(
                'route'     => 'logout',
                'lang'      => 'nav.logout',
                'class'     => '',
                'id'        => '',
                'child'     => array()
            )
        )
    ),
    
    'url' => array(
        'spinner' => '/assets/img/ajax-loader.gif'
    )

);