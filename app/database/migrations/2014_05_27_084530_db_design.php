<?php

use Illuminate\Database\Migrations\Migration;

class DbDesign extends Migration {

	/**
	 * Run the migrations.
	 *
	 * @return void
	 */
	public function up()
	{
		Schema::table('users', function($table) {
			$table->string('org_name');
			$table->string('telephone');
			$table->text('notes');
			$table->integer('language_id');
			$table->softDeletes();
		});

		Schema::create('users_properties', function($table)
		{
			$table->increments('id');
			$table->integer('user_id');
			$table->integer('property_id');
			$table->index('user_id');
			$table->index('property_id');
		});

		Schema::create('properties', function($table)
		{
			$table->increments('id');
			$table->string('property_name');
			$table->string('full_name');
			$table->string('telephone');
			$table->string('email');
			$table->text('notes');
			$table->integer('property_type_id');
			$table->integer('star_rating_id')->nullable();
			$table->integer('total_rooms');
			$table->integer('pms_config_id');
			$table->string('pms_account_ref');
            $table->timestamps();
			$table->softDeletes();
		});

		Schema::create('customisations', function($table)
		{
			$table->increments('id');
			$table->integer('user_id');
			$table->string('logo');
            $table->timestamps();
			$table->index('user_id');
		});

		Schema::create('customisations_colour', function($table)
		{
			$table->increments('id');
			$table->integer('customisation_id');
			$table->string('name', 100);
			$table->string('color', 8);
			$table->index('customisation_id');
		});

		Schema::create('features', function($table)
		{
			$table->increments('id');
			$table->string('name');
			$table->string('template');
			$table->string('slug');
		});

		Schema::create('user_features', function($table)
		{
			$table->increments('id');
			$table->integer('user_id');
			$table->integer('feature_id');
			$table->index('user_id');
			$table->index('feature_id');
		});

		Schema::create('pms_configs', function($table)
		{
			$table->increments('id');
			$table->string('name');
		});

		Schema::create('pms_config_data', function($table)
		{
			$table->increments('id');
			$table->integer('pms_config_id');
			$table->string('name');
			$table->string('value');
			$table->index('pms_config_id');
		});

		Schema::create('star_ratings', function($table)
		{
			$table->increments('id');
			$table->string('name');
		});

		Schema::create('property_types', function($table)
		{
			$table->increments('id');
			$table->string('name');
			$table->boolean('show_stars');
		});

		Schema::create('property_data', function($table)
		{
			$table->increments('id');
			$table->integer('property_id');
			$table->integer('rooms');
			$table->integer('room_revenues');
			$table->integer('f_b_revenues');
			$table->integer('other_revenues');
			$table->integer('total_guests');
			$table->integer('total_checkins');
			$table->timestamps();
			$table->index('property_id');
		});

	}

	/**
	 * Reverse the migrations.
	 *
	 * @return void
	 */
	public function down()
	{
		Schema::table('users', function($t) {
			$t->dropColumn('org_name');
			$t->dropColumn('telephone');
			$t->dropColumn('notes');
			$t->dropColumn('language_id');
		});

		Schema::drop('users_properties');
		Schema::drop('properties');
		Schema::drop('customisations');
		Schema::drop('customisations_colour');
		Schema::drop('features');
		Schema::drop('user_features');
		Schema::drop('pms_configs');
		Schema::drop('pms_config_data');
		Schema::drop('star_ratings');
		Schema::drop('property_types');
		Schema::drop('property_data');
	}

}