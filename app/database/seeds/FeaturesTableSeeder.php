<?php

class FeaturesTableSeeder extends Seeder {

	/**
	 * Run the database seeds.
	 *
	 * @return void
	 */
	public function run()
	{
		$features_count = Features::all()->count();
		if($features_count == 0)
		{
			DB::table('features')->delete();

	        Features::create(array('name' => 'Guest data section', 'template' => 'guest_data_section'));
	        Features::create(array('name' => 'Occupancy', 'template' => 'occupancy'));
	        Features::create(array('name' => 'Average Daily Rate', 'template'=> 'avg_day_rate'));
	        Features::create(array('name' => 'Revenue per room', 'template' => 'revenue_per_avail_room'));
	        Features::create(array('name' => 'Vacancy', 'template' => 'vacancy_rate'));
	        Features::create(array('name' => 'Average people per room', 'template' => 'avg_people_per_room'));
	        Features::create(array('name' => 'Average length of stay', 'template' => 'avg_length_stay'));
	        Features::create(array('name' => 'Total guests', 'template' => 'total_guests'));
	        Features::create(array('name' => 'Total room nights', 'template' => 'total_room_nights'));
	        Features::create(array('name' => 'Total revenue', 'template' => 'total_revenue'));
    	}
	}

}