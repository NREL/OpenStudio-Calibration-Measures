# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class BayesianCalibrationObservableInputs < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Bayesian Calibration Observable Inputs'
  end

  # human readable description
  def description
    return 'This Measure is used to setup the observable inputs Xf: outdoor dry-bulb temperature, the outdoor relative humidity, and the direct solar radiation rate per unit area for a Bayesian Calibration (BC) Analysis.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Output Variables for outdoor dry-bulb temperature, the outdoor relative humidity, and the direct solar radiation rate per unit area are inserted into the model at a user defined reporting frequency.  These are later used by the OpenStudio-Server BC algorithms to create the necessary data.xls files for BC.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
	
    #make an argument for the electric tariff
    reporting_frequency_chs = OpenStudio::StringVector.new
    reporting_frequency_chs << "detailed"
    reporting_frequency_chs << "timestep"
    reporting_frequency_chs << "hourly"
    reporting_frequency_chs << "daily"
    reporting_frequency_chs << "monthly"
    reporting_frequency_chs << "runperiod"
    reporting_frequency = OpenStudio::Measure::OSArgument::makeChoiceArgument('reporting_frequency', reporting_frequency_chs, true)
    reporting_frequency.setDisplayName("Reporting Frequency.")
    reporting_frequency.setDefaultValue("monthly")
    args << reporting_frequency

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    reporting_frequency = runner.getStringArgumentValue("reporting_frequency",user_arguments)

    # report initial condition of model
	outputVariables = model.getOutputVariables 
    runner.registerInitialCondition("The model started with #{outputVariables.size} output variable objects.")

	#add 3 output variables to model for BC
    outputVar1 = OpenStudio::Model::OutputVariable.new("Site Outdoor Air Drybulb Temperature",model)
    outputVar1.setReportingFrequency(reporting_frequency)
	outputVar1.setKeyValue("*")
    runner.registerInfo("Adding output variable for #{outputVar1.variableName} reporting #{reporting_frequency}.")
    runner.registerInfo("Key value for variable is #{outputVar1.keyValue}.")

    outputVar2 = OpenStudio::Model::OutputVariable.new("Site Outdoor Air Relative Humidity",model)
    outputVar2.setReportingFrequency(reporting_frequency)
	outputVar2.setKeyValue("*")
    runner.registerInfo("Adding output variable for #{outputVar2.variableName} reporting #{reporting_frequency}.")
    runner.registerInfo("Key value for variable is #{outputVar2.keyValue}.")
	
	outputVar3 = OpenStudio::Model::OutputVariable.new("Site Direct Solar Radiation Rate per Area",model)
    outputVar3.setReportingFrequency(reporting_frequency)
	outputVar3.setKeyValue("*")
    runner.registerInfo("Adding output variable for #{outputVar3.variableName} reporting #{reporting_frequency}.")
    runner.registerInfo("Key value for variable is #{outputVar3.keyValue}.")
	
    # report final condition of model
    outputVariables = model.getOutputVariables    
    runner.registerFinalCondition("The model finished with #{outputVariables.size} output variable objects.")

    return true
  end
end

# register the measure to be used by the application
BayesianCalibrationObservableInputs.new.registerWithApplication
