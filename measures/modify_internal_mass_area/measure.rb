# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ModifyInternalMassArea < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Modify Internal Mass Area"
  end

  # human readable description
  def description
    return "This measure allows the user to manipulate the exposed area of thermal mass in a model."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This OpenStudio measure takes one input: a thermal mass multiplier. The measure looks for any InternalMass instances and alters the instance multiplier. This measure will only work if thermal mass has already been added to the model. It only alter's internal mass objects, not interior partitions."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # area_multiplier
    area_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("area_multiplier", true)
    area_multiplier.setDisplayName("Thermal Mass Area Multiplier")
    area_multiplier.setDefaultValue(1.0)
    args << area_multiplier

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
    area_multiplier = runner.getDoubleArgumentValue("area_multiplier", user_arguments)

    # check the area_multiplier for reasonableness
    if area_multiplier < 0.0
      runner.registerError("Entery a non-negative multiplier.")
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building has #{model.getInternalMasss.size} internal mass instances..")

    # loop through and alter internal mass multiplier
    altered_masses = []
    model.getInternalMasss.sort.each do |internal_mass|
      initial_multiplier = internal_mass.multiplier
      internal_mass.setMultiplier(initial_multiplier*area_multiplier)
      runner.registerInfo("Chagned multiplier of #{internal_mass.name} from #{initial_multiplier.round(2)} to #{internal_mass.multiplier.round(2)}")
      altered_masses << internal_mass
    end

    # report final condition of model
    runner.registerFinalCondition("Altered #{altered_masses.size} internal mass objects.")

    return true

  end
  
end

# register the measure to be used by the application
ModifyInternalMassArea.new.registerWithApplication
