<?php
/**
 * Sessions Controller Class
 *
 * @package Laravel
 * @subpackage Controllers
 * @category Dashboard Controllers
 */
class DashboardController extends BaseController {

    // --------------------------------------------------------------------
    /**
     * Show the form for creating a new resource.
     *
     * @return View
     */ 
    public function index()
    {    
        $this->data['meta'] = array(
            'title' => Lang::get('meta.dashboard_title')
            );

        return View::make('dashboard.index')->with('meta', $this->data['meta']);
    } 
}
