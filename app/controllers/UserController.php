<?php

/**
 * User Controller Class
 *
 * @package Laravel
 * @subpackage Controllers
 * @category User Controllers
 */
class UserController extends BaseController {

    // --------------------------------------------------------------------

    /**
     * Show the form for creating a new resource.
     *
     * @return View
     */ 
    public function dashboard()
    {
    	if ($this->isAdmin())
		{
			return Redirect::route('admin/dashboard');
		}
        $this->data['meta'] = array(
            'title' => Lang::get('meta.dashboard_title')
            );

        $charts = $this->_dashboard_charts();

        return View::make('user.dashboard')
        ->with('meta', $this->data['meta'])
        ->with('charts', $charts);
    } 

    // --------------------------------------------------------------------

    /**
     * Retrieve dashboard charts
     *
     * @return string
     */
    private function _dashboard_charts()
    {
        $charts = '';
        $dashboard_data = Property_data::dashboard_chart_data(Sentry::getUser()->id);
        $features = Features::user_features(Sentry::getUser()->id);

        foreach($features as $feature)
        {
            if($feature->template != 'guest_data_section')
            {
                $data = $this->_process_dashboard_data($dashboard_data, $feature->template);

                $view = View::make('charts/dashboard/template',
                    array(
                            'template' => $feature->template,
                            'serialised_data' => $data['serialised_data'],
                            'processed_data'=> $data['processed_data'],
                            'filter' => ''

                            )
                        );
                $data = null;
                $charts .= $view->render();
            }
        }

        return $charts;
    }

    // --------------------------------------------------------------------

    /**
     * Process dashboard data
     *
     * @param mixed $dashboard_data
     * @param string $template
     * @return mixed
     */
    private function _process_dashboard_data($dashboard_data, $template)
    {
        $day_data = array('high' => '', 'average' => '', 'low' => '');
        $processed_data = array();
        for($i = 1; $i <= 7; $i++)
        {
            $processed_data[$i] = array('high'=>0, 'low' => 0, 'total' => 0, 'count' => 0, 'info' => array('high'=>'','low'=>''));
            
        }

        $chart_data = array();

        foreach($dashboard_data as $property_data)
        {
            $chart_data[$property_data->day][] = $property_data;

        }

        foreach($chart_data as $day_data)
        {

            $day_data_high = $this->_sort_on_field($day_data, $template, 'DESC');
            

            for($i=0;$i<count($day_data_high);$i++)
            {
                if(isset($day_data_high[$i]->$template))
                {
                    if($i == 0)
                    {
                        $processed_data[$day_data_high[$i]->day]['high'] = number_format($day_data_high[$i]->$template,0,'','');
                        
                    }
                    if($i <= 2)
                    {
                        $processed_data[$day_data_high[$i]->day]['info']['high'] .= '<br/>' . $day_data_high[$i]->property_name . ': '. number_format($day_data_high[$i]->$template,0,'','');
                    }
                    $processed_data[$day_data_high[$i]->day]['total'] += number_format($day_data_high[$i]->$template,0,'','');
                    $processed_data[$day_data_high[$i]->day]['count']++;
                }
            }

            $day_data_low = $this->_sort_on_field($day_data, $template, 'ASC');
            for($i=0;$i<count($day_data_low);$i++)
            {
                if(isset($day_data_high[$i]->$template))
                {
                    if($i == 0)
                    {
                        $processed_data[$day_data_low[$i]->day]['low'] = number_format($day_data_low[$i]->$template,0,'','');
                        
                    }
                    if($i <= 2)
                    {
                        $processed_data[$day_data_low[$i]->day]['info']['low'] .= '<br/>' . $day_data_low[$i]->property_name . ': '. number_format($day_data_low[$i]->$template,0,'','');
                    }
                }
                
            }
            
        }

        $processed_data = array_reverse($processed_data);
        array_unshift($processed_data, null);
        unset($processed_data[0]);


        $serialised_data = array('high' => '', 'low' => '', 'average' => '');

        foreach($processed_data as $data)
        {
            $serialised_data['high'] .= ($serialised_data['high'] != '')? ','. $data['high'] : $data['high'];
            $serialised_data['low'] .= ($serialised_data['low'] != '')? ','. $data['low'] : $data['low'];
            if($data['count'])
            {
                $serialised_data['average'] .= ($serialised_data['average'] != '')? ','. number_format($data['total']/$data['count'], 0,'','') : number_format($data['total']/$data['count'], 0,'','');
            }
            else
            {
                $serialised_data['average'] .= ($serialised_data['average'] != '')? ',0' : '0';
            }
        }

        $results = array('processed_data' => $processed_data, 'serialised_data' => $serialised_data);

        return $results;
    }

    // --------------------------------------------------------------------

    /**
     * Sort object based on key value
     *
     * @param mixed $object
     * @param string $key
     * @param string $order
     * @return mixed
     */
    private function _sort_on_field($object, $key, $order = 'ASC')
    { 
        usort($object, function($a,$b) use ($key, $order){
            if(isset($a->{$key}))
            {
                if($order === 'DESC')
                {
                    return  ((int) $a->$key - (int) $b->$key) * -1;
                }
                else
                {
                   return  ((int) $a->$key - (int) $b->$key) * 1; 
                }
            }
            
        }); 

        return $object;
    }

    // --------------------------------------------------------------------

    /**
     * Refresh a dashboard_chart
     *
     * @return json
     */
    public function refresh_dashboard_chart()
    {
        //prepare data for validation
        $data = array(
            'template' => Request::get('template'),
            'filter' => Request::get('filter'),
        );
        
        //validation rule for data
        $rules = array( 
            'template' => 'required', 
        );

        //add validation for data and rules
        $validator = Validator::make($data, $rules);
        if($validator->fails()) {
            exit;
        }

        $dashboard_data = Property_data::dashboard_chart_data(Sentry::getUser()->id, $data['filter']);
        $processed_data = $this->_process_dashboard_data($dashboard_data, $data['template']);

        $view = View::make('charts/dashboard/template',
            array(
                    'template' => $data['template'],
                    'serialised_data' => $processed_data['serialised_data'],
                    'processed_data'=> $processed_data['processed_data'],
                    'filter' => $data['filter'],
                    'child' => true
                    )
                );
        $data = null;

        return array('chart' => $view->render());
        exit;
    }

    // --------------------------------------------------------------------

}