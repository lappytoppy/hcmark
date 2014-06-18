<?php 

class Property_data extends Eloquent {

    /**
     * The database table used by the model.
     *
     * @var string
     */
    protected $table = 'property_data';  

    public $timestamps = true;

    /**
     * Retrive dashboard chart data
     *
     * @param int $user_id
     * @param string $filter
     * @return mixed
     */
    public static function dashboard_chart_data($user_id, $filter = false)
    {
    	switch ($filter) {
    		case 'all_hotels':
    			$filter = "AND property_types.name = 'Hotel'";
    			break;
     		case 'all_apartments':
     			$filter = "AND property_types.name = 'Apartment'";
    			break;
    		case '5_star_hotels':
    			$filter = "AND star_ratings.name = '5'";
    			break;
      		case '4_star_hotels':
      			$filter = "AND star_ratings.name = '4'";
    			break;
     		case '3_star_hotels':
     			$filter = "AND star_ratings.name = '3'";
    			break;
     		case '2_star_hotels':
     			$filter = "AND star_ratings.name = '2'";
    			break;
    		case '1_star_hotels':
    			$filter = "AND star_ratings.name = '1'";
    			break;
      		case 'other_hotels':
      			$filter = "AND (star_rating_id is NULL or star_rating_id = 0) AND property_types.name != 'Apartment'";
    			break;  		
    		default:
    			$filter = '';
    			break;
    	}

    	$results = DB::select(DB::raw("SELECT
			property_id,
			property_name,
			(DATEDIFF(NOW(), property_data.created_at)) as day,
			ROUND(((rooms/total_rooms) * 100),0) AS occupancy,
			ROUND((room_revenues/total_rooms), 2) AS revenue_per_avail_room,
			ROUND((room_revenues/rooms), 2) AS avg_day_rate,
			ROUND(((total_rooms)-rooms)/(total_rooms) * 100, 0) AS vacancy_rate,
			ROUND((total_guests/(rooms)), 2) AS avg_people_per_room,
			ROUND((total_guests/total_checkins), 2) AS avg_length_stay,
			(total_guests) AS total_guests,
			(rooms) AS total_room_nights,
			ROUND((room_revenues+f_b_revenues+other_revenues),2) AS total_revenue,
			property_types.name as property_type,
			star_ratings.name as rating
			FROM property_data
			INNER JOIN properties 
			ON properties.id = property_data.property_id
			LEFT JOIN star_ratings
			ON properties.star_rating_id = star_ratings.id
			LEFT JOIN property_types
			ON properties.property_type_id = property_types.id
			WHERE EXISTS (SELECT id FROM users_properties
			                WHERE user_id = :user_id and users_properties.property_id = property_data.property_id)
			AND
			DATEDIFF(NOW(), property_data.created_at) <= 7
			{$filter}
			ORDER BY day ASC"), 
			array(
	 		  'user_id' => $user_id,
	 		)
 		);
	
		return $results;
    	
    }


}