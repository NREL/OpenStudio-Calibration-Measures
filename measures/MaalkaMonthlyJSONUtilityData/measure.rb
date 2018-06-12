#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'json'
require 'time'

#start the measure
class MaalkaMonthlyJSONUtilityData < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Maalka Formatted Monthly JSON Utility Data"
  end

  # human readable description
  def description
    return "Maalka Formatted Monthly JSON Utility Data"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Add Maalka Formatted Monthly JSON Utility Data to OSM as a UtilityBill Object"
  end
  
  def year_month_day(str)
    result = nil
    if match_data = /(\d+)(\D)(\d+)(\D)(\d+)/.match(str)
      if match_data[1].size == 4 #yyyy-mm-dd
        year = match_data[1].to_i
        month = match_data[3].to_i
        day = match_data[5].to_i
        result = [year, month, day]
      elsif match_data[5].size == 4 #mm-dd-yyyy
        year = match_data[5].to_i
        month = match_data[1].to_i
        day = match_data[3].to_i
        result = [year, month, day]     
      end
    else
      puts "no match for '#{str}'"
    end
    return result
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #set path to json
    json = OpenStudio::Ruleset::OSArgument::makeStringArgument("json",true)
    json.setDisplayName("JSON file name.")
    json.setDescription("Name of the JSON file to import data from. This is the filename with the extension (e.g. NewWeather.epw). Optionally this can inclucde the full file path, but for most use cases should just be file name.")
    args << json
    
    #make a start date argument
    start_date = OpenStudio::Ruleset::OSArgument::makeStringArgument("start_date",true)
    start_date.setDisplayName("Start date")
    start_date.setDescription("Start date format %Y%m%dT%H%M%S with Hour Min Sec optional")
    start_date.setDefaultValue("2013-01-1")
    args << start_date
    
    #make an end date argument
    end_date = OpenStudio::Ruleset::OSArgument::makeStringArgument("end_date",true)
    end_date.setDisplayName("End date")
    end_date.setDescription("End date format %Y%m%dT%H%M%S with Hour Min Sec optional")
    end_date.setDefaultValue("2013-12-31")
    args << end_date
    
    #make an end date argument
    remove_utility_bill_data = OpenStudio::Ruleset::OSArgument::makeBoolArgument("remove_existing_data",true)
    remove_utility_bill_data.setDisplayName("remove all existing Utility Bill data objects from model")
    remove_utility_bill_data.setDescription("remove all existing Utility Bill data objects from model")
    remove_utility_bill_data.setDefaultValue(false)
    args << remove_utility_bill_data
    
    #make an end date argument
    set_runperiod = OpenStudio::Ruleset::OSArgument::makeBoolArgument("set_runperiod",true)
    set_runperiod.setDisplayName("Set RunPeriod Object in model to use start and end dates")
    set_runperiod.setDescription("Set RunPeriod Object in model to use start and end dates.  Only needed once if multiple copies of measure being used.")
    set_runperiod.setDefaultValue(false)
    args << set_runperiod
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    json = runner.getStringArgumentValue("json",user_arguments)
    start_date = runner.getStringArgumentValue("start_date",user_arguments)
    end_date = runner.getStringArgumentValue("end_date",user_arguments)
    remove_utility_bill_data = runner.getBoolArgumentValue("remove_existing_data",user_arguments)
    set_runperiod = runner.getBoolArgumentValue("set_runperiod",user_arguments)
    
    # set start date
    if date = year_month_day(start_date)
      start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(date[1]), date[2], date[0])    
      # actual year of start date
      yearDescription = model.getYearDescription()
      yearDescription.setCalendarYear(date[0])
      if set_runperiod
        runPeriod = model.getRunPeriod()
        runPeriod.setBeginMonth(date[1])
        runPeriod.setBeginDayOfMonth(date[2])
        runner.registerInfo("RunPeriod start date set to #{start_date}")
      end
    else
      runner.registerError("Unknown start date '#{start_date}'")
      fail "Unknown start date '#{start_date}'"
      return false
    end
    
    # set end date
    if date = year_month_day(end_date)    
      end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(date[1]), date[2], date[0])
      if set_runperiod
        runPeriod = model.getRunPeriod()
        runPeriod.setEndMonth(date[1])
        runPeriod.setEndDayOfMonth(date[2])
        runner.registerInfo("RunPeriod end date set to #{end_date}")
      end
    else
      runner.registerError("Unknown end date '#{end_date}'")
      fail "Unknown end date '#{end_date}'"
      return false
    end

    # remove all utility bills
    if remove_utility_bill_data
      model.getUtilityBills.each do |bill|
        bill.remove
      end
    end

    # find json file
    osw_file = runner.workflow.findFile(json)
    json_path = nil
    if osw_file.is_initialized
      json_path = osw_file.get.to_s
    else
      runner.registerError("Did not find #{json} in paths described in OSW file.")
      return false
    end

    # OS fuel types key json value is os
    fuel_types = {}
    fuel_types['electric'] = {'fuel' => 'Electricity', 'units' => 'kWh', 'data_key_name' => 'tot_kwh' }
    fuel_types['naturalGas'] = {'fuel' => 'NaturalGas', 'units' => 'therms', 'data_key_name' => 'tot_therms' }

    # parse json file
    temp = File.read(json_path)
    json_data = JSON.parse(temp)  
    if not json_data.nil?

      # gather building inputs
      runner.registerValue('bldg_type_a',json_data['data']['maalka_input']['building']['primary_building_type'])
      runner.registerValue('total_bldg_floor_area',json_data['data']['maalka_input']['building']['primary_building_type'])
      if !json_data['data']['maalka_input']['building']['floors_above_grade'] == "null"
        runner.registerValue('total_bldg_floor_area',json_data['data']['maalka_input']['building']['floors_above_grade'])
      end
      runner.registerValue('zipcode',json_data['data']['maalka_input']['building']['postal_code'])

      # todo - add more advanced logic to infer tempalte from year build current code just shows basic concept
      # lookup template
      year_built = json_data['data']['maalka_input']['building']['year_built'].to_i
      runner.registerValue('year_built',year_built)
      template = nil
      if year_built < 1980
        template = 'DOE Ref Pre-1980'
      elsif year_built < 2004
        template = 'DOE Ref 1980-2004'
      elsif year_built < 2007
        template = '90.1-2004'
      elsif year_built < 2010
        template = '90.1-2007'
      elsif year_built < 2013
        template = "90.1-2010"
      else
        template = "90.1-2013"
      end
      runner.registerValue('template',template)

      json_data['data']['maalka_input'].each do |key,value|
        next if key == "building"
        fuel_type = fuel_types[key]['fuel'].to_s
        periods = value['data']

        utilityBill = OpenStudio::Model::UtilityBill.new("#{fuel_type}".to_FuelType, model)
        utilityBill.setName("#{fuel_type}")
        utilityBill.setConsumptionUnit("#{fuel_types['units']}")
        #TODO trap nil
        runner.registerInfo("Adding utility bills for #{fuel_type}")

        periods.each do |period|

          begin
            from_date = period['from'] ? Time.iso8601(period['from']).strftime("%Y%m%dT%H%M%S") : nil
            to_date = period['to'] ? Time.iso8601(period['to']).strftime("%Y%m%dT%H%M%S") : nil
          rescue ArgumentError => e
            runner.registerError("Unknown date format in period '#{period}'")
          end
          if from_date.nil? or to_date.nil?
            runner.registerError("Unknown date format in period '#{period}'")
            fail "Unknown date format in period '#{period}'"
            return false
          end
          period_start_date = OpenStudio::DateTime.fromISO8601(from_date).get.date
          period_end_date = OpenStudio::DateTime.fromISO8601(to_date).get.date

          if (period_start_date < start_date) or (period_end_date > end_date)
            runner.registerInfo("skipping period #{period_start_date} to #{period_end_date}")
            next
          end

          data_key_name = fuel_types[key]['data_key_name']
          if period["#{data_key_name}"].nil?
            runner.registerError("Billing period missing key:#{data_key_name} in: '#{period}'")
            return false
          end
          data_key_value = period["#{data_key_name}"].to_f

          # peak_kw = nil
          # if not period['peak_kw'].nil?
          # peak_kw = period['peak_kw'].to_f
          # end

          runner.registerInfo("period #{period}")
          runner.registerInfo("period_start_date: #{period_start_date}, period_end_date: #{period_end_date}, #{data_key_name}: #{data_key_value}")

          bp = utilityBill.addBillingPeriod()
          bp.setStartDate(period_start_date)
          bp.setEndDate(period_end_date)
          bp.setConsumption(data_key_value)
          # if peak_kw
          # bp.setPeakDemand(peak_kw)
          # end

        end

      end
    end
    
    #reporting final condition of model
    runner.registerFinalCondition("Utility bill data has been added to the model.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
MaalkaMonthlyJSONUtilityData.new.registerWithApplication