<?php

class PropertiesDataSeeder extends Seeder {

	/**
	 * Run the database seeds.
	 *
	 * @return void
	 */
	public function run()
	{
		$property_count = Properties::all()->count();
		if($property_count == 0)
		{
			DB::table('properties')->delete();
			DB::table('property_data')->delete();
			DB::table('property_types')->delete();
			DB::table('star_ratings')->delete();

			$property_types = array(
	        		array('name' => 'Hotel', 'show_stars' => 1),
	        		array('name' => 'Apartment', 'show_stars' => 0)
	        	);
			foreach($property_types as $type)
			{
				Property_types::create(array('name' => $type['name'], 'show_stars' => $type['show_stars']));
			}

			$star_ratings = array(
	        		array('name' => '1'),
	        		array('name' => '2'),
	        		array('name' => '3'),
	        		array('name' => '4'),
	        		array('name' => '5'),
	        	);

			foreach($star_ratings as $rating)
			{
				Star_ratings::create(array('name' => $rating['name']));
			}

			$properties = $this->_parse_properties();

			foreach($properties as $property)
			{
				if(isset($property['property_name']))
				{
					$star_rating_id = 0;
					if(isset($property['star_rating']))
						$star_rating_id = Star_ratings::where('name', $property['star_rating'])->pluck('id');

					$property_type_id = 0;
					if(isset($property['property_type']))
						$property_type_id = Property_types::where('name', $property['property_type'])->pluck('id');

					$property_id = Properties::insertGetId(
						array(
							'property_name' => $property['property_name'],
							'property_type_id' => $property_type_id,
							'star_rating_id' => $star_rating_id,
							'total_rooms' => $property['total_rooms']
						)
					);

					if(isset($property['occupied_rooms']))
					{
						for($i = 0; $i < count($property['occupied_rooms']); $i++)
						{
							$property_data_id = Property_data::insertGetId(
								array(
									'property_id' => $property_id,
									'rooms' => $property['occupied_rooms'][$i]['rooms'],
									'room_revenues' => $property['room_revenues'][$i]['revenue'],
									'f_b_revenues' => $property['f_b_revenues'][$i]['revenue'],
									'other_revenues' => $property['other_revenues'][$i]['revenue'],
									'total_guests' => $property['total_guests'][$i]['guests'],
									'total_checkins' => $property['total_checkins'][$i]['guests'],
									'created_at' => $property['occupied_rooms'][$i]['date'],
									'updated_at' => $property['occupied_rooms'][$i]['date']
								)
							);
						}
					}
				}
			}


    	}

	}

	/**
	 * Parse properties
	 * @return array
	 */
	private function _parse_properties()
	{
		$file_path = app_path();
		$file_path .= '/database/seeds/data/';

		// Properties
		$file = fopen($file_path . "properties.csv","r");
		$headings = array('property_name', 'property_type', 'star_rating', 'total_rooms');

		$properties = array();
		$i = 0;
		while(! feof($file))
		{
			if($p = fgetcsv($file))
			{
				$property = array_combine($headings, $p);
				if($property['property_name'])
				{
					$properties[$i] = $property;
					$i++;
				}
			}
		}
		fclose($file);

		// Rooms Occupied
		$properties = $this->_parse_property_data($properties, $file_path, 'rooms_occupied', 'occupied_rooms', 'rooms');
		// Total Room Revenues
		$properties = $this->_parse_property_data($properties, $file_path, 'total_room_revenues', 'room_revenues', 'revenue');
		// Food & Beverage Revenues
		$properties = $this->_parse_property_data($properties, $file_path, 'f_b_revenues', 'f_b_revenues', 'revenue');
		// Other Revenues
		$properties = $this->_parse_property_data($properties, $file_path, 'other_revenues', 'other_revenues', 'revenue');
		// Total Guests
		$properties = $this->_parse_property_data($properties, $file_path, 'total_guests', 'total_guests', 'guests');
		// Total Checkins
		$properties = $this->_parse_property_data($properties, $file_path, 'total_checkins', 'total_checkins', 'guests');

		return $properties;
	}

	/**
	 * Parse property data
	 * @param  array $properties
	 * @param  string $file_name
	 * @param  string $key
	 * @param  string $name
	 * @return array
	 */
	private function _parse_property_data($properties, $file_path, $file_name, $key, $name)
	{
		$file = fopen($file_path . $file_name . ".csv","r");

		$i = 0;
		while(! feof($file))
		{

			$row = fgetcsv($file);

			for($j = 0; $j <= count($row); $j++)
			{
				if(isset($row[$j]) && $row[$j])
				{
					$f = 90 - $i;
					$d = "-{$f} days";
					$properties[$j][$key][] = array($name => $row[$j], 'date' => date("Y-m-d", strtotime($d)));
				}
				else
				{
					$f = 90 - $i;
					$d = "-{$f} days";
					$properties[$j][$key][] = array($name => 0, 'date' => date("Y-m-d", strtotime($d)));
				}
			}
			$i++;
		}

		fclose($file);

		return $properties;
	}

}