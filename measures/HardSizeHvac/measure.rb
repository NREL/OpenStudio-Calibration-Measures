# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class HardSizeHVAC < OpenStudio::Ruleset::ModelUserScript

  require 'openstudio-standards'

  # human readable name
  def name
    return "Hard Size HVAC"
  end

  # human readable description
  def description
    return "Run a simulation to autosize HVAC equipment and then apply these autosized values back to the model."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Run a simulation to autosize HVAC equipment and then apply these autosized values back to the model."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Require the HVAC sizing library
    #require_relative 'resources/HVACSizing.Model'

    # Run a sizing run and attach the resulting
    # sql file to the model.  Hard sizing methods
    # won't work unless the model has a sql file.
    model.runSizingRun("#{Dir.pwd}")    

    # Hard sizing every object in the model.
    model.applySizingValues

    # Log the openstudio-standards messages to the runner
    log_messages_to_runner(runner, false)
  
    return true

  end
  
end

# register the measure to be used by the application
HardSizeHVAC.new.registerWithApplication
