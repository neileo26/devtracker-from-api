require 'sinatra'
require 'json'
require 'rest-client'
require 'active_support'
require 'kramdown'
require 'pony'
require 'money'
#require 'oj'

#helpers path
require_relative 'helpers/formatters.rb'
require_relative 'helpers/oipa_helpers.rb'
require_relative 'helpers/codelists.rb'
require_relative 'helpers/lookups.rb'
require_relative 'helpers/common_helpers.rb'
require_relative 'helpers/project_helpers.rb'
require_relative 'helpers/sector_helpers.rb'
require_relative 'helpers/country_helpers.rb'
require_relative 'helpers/document_helpers.rb'
require_relative 'helpers/common_helpers.rb'
require_relative 'helpers/results_helper.rb'
require_relative 'helpers/JSON_helpers.rb'
require_relative 'helpers/filters_helper.rb'

#Helper Modules
include CountryHelpers
include Formatters
include SectorHelpers
include ProjectHelpers
include CommonHelpers
include ResultsHelper
include FiltersHelper

# Developer Machine: set global settings
set :oipa_api_url, 'http://dfid-oipa.zz-clients.net/api/'

# Server Machine: set global settings
#set :oipa_api_url, 'http://127.0.0.1:6081/api/'

#ensures that we can use the extension html.erb rather than just .erb
Tilt.register Tilt::ERBTemplate, 'html.erb'


#####################################################################
#  Common Variable Assingment
#####################################################################

set :current_first_day_of_financial_year, first_day_of_financial_year(DateTime.now)
set :current_last_day_of_financial_year, last_day_of_financial_year(DateTime.now)


#####################################################################
#  HOME PAGE
#####################################################################

get '/' do  #homepage
	#read static data from JSON files for the front page
	top5results = JSON.parse(File.read('data/top5results.json'))

	countriesJSON = RestClient.get settings.oipa_api_url + "activities/aggregations?reporting_organisation=GB-1&group_by=recipient_country&aggregations=budget&budget_period_start=#{settings.current_first_day_of_financial_year}&budget_period_end=#{settings.current_last_day_of_financial_year}&order_by=-budget&page_size=5"
  	top5countries = JSON.parse(countriesJSON)
  	sectorValuesJSON = RestClient.get settings.oipa_api_url + "activities/aggregations?reporting_organisation=GB-1&group_by=sector&aggregations=budget&format=json"
 	erb :index, 
 		:layout => :'layouts/layout', 
 		:locals => {
 			top_5_countries: top5countries['results'], 
 			what_we_do: high_level_sector_list( sectorValuesJSON, "top_five_sectors", "High Level Code (L1)", "High Level Sector Description"), 
 			what_we_achieve: top5results 	
 		}
end

#####################################################################
#  COUNTRY PAGES
#####################################################################

# Country summary page
get '/countries/:country_code/?' do |n|
    country = get_country_details(n)
    results = get_country_results(n)
    countryYearWiseBudgets= get_country_yearwise_budget_graph_data(n)
	countrySectorGraphData = get_country_sector_graph_data(RestClient.get settings.oipa_api_url + "activities/aggregations?reporting_organisation=GB-1&order_by=-budget&group_by=sector&aggregations=budget&format=json&related_activity_recipient_country=#{n}")
	
	erb :'countries/country', 
		:layout => :'layouts/layout',
		:locals => {
 			country: country,
 			countryYearWiseBudgets: countryYearWiseBudgets,
 			countrySectorGraphData: countrySectorGraphData,
 			results: results
 		}
end

#Country Project List Page
get '/countries/:country_code/projects/?' do |n|
	countryAllProjectFilters = JSON.parse(File.read('data/countryProjectsFilters.json'))
	country=countriesInfo.select {|country| country['code'] == n}.first
	results = resultsInfo.select {|result| result['code'] == n}
	#oipa_total_projects = RestClient.get settings.oipa_api_url + "activities?reporting_organisation=GB-1&hierarchy=1&related_activity_recipient_country=#{n}&format=json&page_size=10&page=1"
    #total_projects = JSON.parse(oipa_total_projects)
	oipa_project_list = RestClient.get settings.oipa_api_url + "activities?hierarchy=1&format=json&reporting_organisation=GB-1&page_size=10&fields=description,activity_status,iati_identifier,url,title,reporting_organisations,activity_aggregations&activity_status=1,2,3,4,5&ordering=-total_child_budget_value&related_activity_recipient_country=#{n}"
	projects= JSON.parse(oipa_project_list)
	sectorValuesJSON = RestClient.get settings.oipa_api_url + "activities/aggregations?format=json&group_by=sector&aggregations=count&reporting_organisation=GB-1&related_activity_recipient_country=#{n}"
	highLevelSectorList = high_level_sector_list_filter(sectorValuesJSON)
	#projects = projects_list['results']
	project_budget_higher_bound = 0
	actualStartDate = '0000-00-00T00:00:00' 
	plannedEndDate = '0000-00-00T00:00:00'
	unless projects['results'][0].nil?
		project_budget_higher_bound = projects['results'][0]['activity_aggregations']['total_child_budget_value']
	end
	actualStartDate = RestClient.get settings.oipa_api_url + "activities?format=json&page_size=1&fields=activity_dates&reporting_organisation=GB-1&hierarchy=1&related_activity_recipient_country=#{n}&ordering=actual_start_date"
	actualStartDate = JSON.parse(actualStartDate)
	unless actualStartDate['results'][0].nil? 
		actualStartDate = actualStartDate['results'][0]['activity_dates'][1]['iso_date']
	end
	plannedEndDate = RestClient.get settings.oipa_api_url + "activities?format=json&page_size=1&fields=activity_dates&reporting_organisation=GB-1&hierarchy=1&related_activity_recipient_country=#{n}&ordering=-planned_end_date"
	plannedEndDate = JSON.parse(plannedEndDate)
	unless plannedEndDate['results'][0].nil?
		plannedEndDate = plannedEndDate['results'][0]['activity_dates'][2]['iso_date']
	end
	erb :'countries/projects', 
		:layout => :'layouts/layout',
		:locals => {
			oipa_api_url: settings.oipa_api_url,
	 		country: country,
	 		total_projects: projects['count'],
	 		projects: projects['results'],
	 		results: results,
	 		highLevelSectorList: highLevelSectorList,
	 		budgetHigherBound: project_budget_higher_bound,
	 		countryAllProjectFilters: countryAllProjectFilters,
	 		actualStartDate: actualStartDate,
	 		plannedEndDate: plannedEndDate
	 		}
		 			
end

#Country Results Page
get '/countries/:country_code/results/?' do |n|		
	country = get_country_code_name(n)
	results = get_country_results(n)
	resultsPillar = results_pillar_wise_indicators(n,results)
    totalProjects = get_country_total_project(n)
	
	erb :'countries/results', 
		:layout => :'layouts/layout',
		:locals => {
	 		country: country,
	 		totalProjects: totalProjects,
	 		results: results,
	 		resultsPillar: resultsPillar
	 		}
		 			
end

#####################################################################
#  PROJECTS PAGES
#####################################################################

# Project summary page
get '/projects/:proj_id/?' do |n|
	# get the project data from the API
  	project = get_h1_project_details(n)

  	#get the country/region data from the API
  	countryOrRegion = get_country_or_region(n)

  	#get total project budget and spend Data
  	projectBudget = get_project_budget(n)

  	#get project sectorwise graph  data
  	projectSectorGraphData = get_project_sector_graph_data(n)
  	
	# get the funding projects Count from the API
  	fundingProjectsCount = get_funding_project_count(n)

	# get the funded projects Count from the API
	fundedProjectsCount = get_funded_project_count(n)
	
	erb :'projects/summary', 
		:layout => :'layouts/layout',
		 :locals => {
 			project: project,
 			countryOrRegion: countryOrRegion,	 					 			
 			fundedProjectsCount: fundedProjectsCount,
 			fundingProjectsCount: fundingProjectsCount,
 			projectBudget: projectBudget,
 			projectSectorGraphData: projectSectorGraphData
 		}
end

# Project documents page
get '/projects/:proj_id/documents/?' do |n|
	# get the project data from the API
	project = get_h1_project_details(n)

  	#get the country/region data from the API
  	countryOrRegion = get_country_or_region(n)

  	# get the funding projects Count from the API
  	fundingProjectsCount = get_funding_project_count(n)

	# get the funded projects Count from the API
	fundedProjectsCount = get_funded_project_count(n)
  	
	erb :'projects/documents', 
		:layout => :'layouts/layout',
		:locals => {
 			project: project,
 			countryOrRegion: countryOrRegion,
 			fundedProjectsCount: fundedProjectsCount,
 			fundingProjectsCount: fundingProjectsCount 
 		}
end

#Project transactions page
get '/projects/:proj_id/transactions/?' do |n|
	# get the project data from the API
	project = get_h1_project_details(n)
		
	# get the transactions from the API
  	transactions = get_transaction_details(n)

  	# get yearly budget for H1 Activity from the API
	projectYearWiseBudgets= get_project_yearwise_budget(n)
	
	#get the country/region data from the API
  	countryOrRegion = get_country_or_region(n)

    # get the funding projects Count from the API
  	fundingProjectsCount = get_funding_project_count(n)

	# get the funded projects Count from the API
	fundedProjectsCount = get_funded_project_count(n)
	
	erb :'projects/transactions', 
		:layout => :'layouts/layout',
		:locals => {
			project: project,
			countryOrRegion: countryOrRegion,
 			transactions: transactions,
 			projectYearWiseBudgets: projectYearWiseBudgets, 			
 			fundedProjectsCount: fundedProjectsCount,
 			fundingProjectsCount: fundingProjectsCount 
 		}
end

#Project partners page
get '/projects/:proj_id/partners/?' do |n|
	# get the project data from the API
	project = get_h1_project_details(n)

  	#get the country/region data from the API
  	countryOrRegion = get_country_or_region(n)

  	# get the funding projects from the API
  	fundingProjectsData = get_funding_project_details(n)
  	fundingProjects = fundingProjectsData['results'].select {|project| !project['provider_organisation'].nil? }	

	# get the funded projects from the API
	fundedProjectsData = get_funded_project_details(n)

	erb :'projects/partners', 
		:layout => :'layouts/layout',
		:locals => {
			project: project,
			countryOrRegion: countryOrRegion, 			
 			fundedProjects: fundedProjectsData['results'],
 			fundedProjectsCount: fundedProjectsData['count'],
 			fundingProjects: fundingProjects,
 			fundingProjectsCount: fundingProjectsData['count']
 		}
end

#####################################################################
#  SECTOR PAGES
#####################################################################
# examples:
# http://devtracker.dfid.gov.uk/sector/

# High Level Sector summary page
get '/sector/?' do
	# Get the high level sector data from the API
	sectorValuesJSON = RestClient.get settings.oipa_api_url + "activities/aggregations?reporting_organisation=GB-1&group_by=sector&aggregations=budget&format=json"
  	erb :'sector/index', 
		:layout => :'layouts/layout',
		 :locals => {
 			high_level_sector_list: high_level_sector_list( sectorValuesJSON, "all_sectors", "High Level Code (L1)", "High Level Sector Description")
 		}		
end

# Category Page (e.g. Three Digit DAC Sector) 
get '/sector/:high_level_sector_code/?' do
	# Get the three digit DAC sector data from the API
  	erb :'sector/categories', 
		:layout => :'layouts/layout',
		 :locals => {
 			category_list: sector_parent_data_list( settings.oipa_api_url, "category", "Category (L2)", "Category Name", "High Level Code (L1)", "High Level Sector Description", params[:high_level_sector_code], "category")
 		}		
end

# Sector Page (e.g. Five Digit DAC Sector) 
get '/sector/:high_level_sector_code/categories/:category_code/?' do
	# Get the three digit DAC sector data from the API
  	erb :'sector/sectors', 
		:layout => :'layouts/layout',
		 :locals => {
 			sector_list: sector_parent_data_list(settings.oipa_api_url, "sector", "Code (L3)", "Name", "Category (L2)", "Category Name", params[:high_level_sector_code], params[:category_code])
 		}		
end




#####################################################################
#  COUNTRY REGION & GLOBAL PROJECT MAP PAGES
#####################################################################

#Aid By Location Page
get '/location/country/?' do
	erb :'location/country/index', 
		:layout => :'layouts/layout',
		:locals => {
			:dfid_country_map_data => 	dfid_country_map_data,
			:dfid_complete_country_list => 	dfid_complete_country_list
		}
end

# Aid by Region Page
get '/location/regional/?' do 
	erb :'location/regional/index', 
		:layout => :'layouts/layout',
		:locals => {
			#TODO Get the data structure in here
			:dfid_regional_projects_data => dfid_regional_projects_data			
		}
end

# Aid by Region Page
get '/location/global/?' do 
	erb :'location/global/index', 
		:layout => :'layouts/layout',
		:locals => {
			#TODO Get the data structure in here
			:dfid_regional_projects_data => dfid_global_projects_data			
		}
end

#####################################################################
#  Search PAGE
#####################################################################

get '/search/?' do
	countryAllProjectFilters = JSON.parse(File.read('data/countryProjectsFilters.json'))
	query = params['query']
	#Sample Api call - http://&fields=activity_status,iati_identifier,url,title,reporting_organisations,activity_aggregations
	oipa_project_list = RestClient.get settings.oipa_api_url + "activities?hierarchy=1&format=json&page_size=10&fields=description,activity_status,iati_identifier,url,title,reporting_organisations,activity_aggregations&q=#{query}&activity_status=1,2,3,4,5&ordering=-total_child_budget_value"
	projects_list= JSON.parse(oipa_project_list)
	projects = projects_list['results']
	project_budget_higher_bound = projects_list['results'][0]['activity_aggregations']['total_child_budget_value']
	project_count = projects_list['count']
	sectorValuesJSON = RestClient.get settings.oipa_api_url + "activities/aggregations?format=json&group_by=sector&aggregations=count&q=#{query}"
	highLevelSectorList = high_level_sector_list_filter( sectorValuesJSON)
	erb :'search/search',
	:layout => :'layouts/layout',
	:locals => {
		oipa_api_url: settings.oipa_api_url,
		projects: projects,
		project_count: project_count,
		:query => query,
		countryAllProjectFilters: countryAllProjectFilters,
		budgetHigherBound: project_budget_higher_bound,
		highLevelSectorList: highLevelSectorList
	}
end

#####################################################################
#  STATIC PAGES
#####################################################################


get '/department' do 
	erb :'department/department', :layout => :'layouts/layout'
end

get '/about/?' do
	erb :'about/about', :layout => :'layouts/layout'
end

get '/cookies/?' do
	erb :'cookies/index', :layout => :'layouts/layout'
end  

get '/faq/?' do
	erb :'faq/faq', :layout => :'layouts/layout'
end 

get '/feedback/?' do
	erb :'feedback/index', :layout => :'layouts/layout'
end 

post '/feedback/index' do
 Pony.mail({
	:from => "devtracker-feedback@dfid.gov.uk",
    :to => "devtracker-feedback@dfid.gov.uk",
    :subject => "DevTracker Feedback",
    :body => "<p>" + params[:email] + "</p><p>" + params[:name] + "</p><p>" + params[:description] + "</p>",
    :via => :smtp,
    :via_options => {
     :address              => '127.0.0.1',
     :port                 => '25'
     }
    })
    redirect '/' 
end

get '/fraud/?' do
	erb :'fraud/index', :layout => :'layouts/layout'
end  

post '/fraud/index' do
 Pony.mail({
	:from => "devtracker-feedback@dfid.gov.uk",
    :to => "devtracker-feedback@dfid.gov.uk",
    :subject => params[:country] + " " + params[:project],
    :body => "<p>" + params[:country] + "</p>" + "<p>" + params[:project] + "</p>" + "<p>" + params[:description] + "</p>" + "<p>" + params[:name] + "</p>" + "<p>" + params[:email] + "</p>" + "<p>" + params[:telno] + "</p>",
    :via => :smtp,
    :via_options => {
     :address              => '127.0.0.1',
     :port                 => '25'
     }
    })
    redirect '/' 
end
