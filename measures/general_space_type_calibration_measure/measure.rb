

# start the measure
class GeneralSpaceTypeCalibrationMeasure < OpenStudio::Ruleset::ModelUserScript

  # require all .rb files in resources folder
  Dir[File.dirname(__FILE__) + '/resources/*.rb'].each {|file| require file }
  # resource file modules
  include OsLib_HelperMethods
  
  # human readable name
  def name
    return " General Space Type Calibration Measure"
  end

  # human readable description
  def description
    return "This is a general purpose measure to calibrate space type elements."
  end

  # human readable description of modeling approach
  def modeler_description
    return "It will have a single loop through space types. Initially it will be used for calibration of people, infiltration, and outdoor air. It doesn't have to hit the space type json file since it is just adjusting by a multiplier."
  end
  
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # occupancy multiplier
    multiplier_occ = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("multiplier_occ", true)
    multiplier_occ.setDisplayName("Occupancy Multiplier")
    multiplier_occ.setDescription("For each space type multiply the default number of people by this value.")
    multiplier_occ.setDefaultValue(1.0)
    args << multiplier_occ

    # multiplier for infiltration
    multiplier_infiltration = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("multiplier_infiltration", true)
    multiplier_infiltration.setDisplayName("Infiltration Multiplier")
    multiplier_infiltration.setDescription("For each space type multiply the default infiltration value by this.")
    multiplier_infiltration.setDefaultValue(1.0)
    args << multiplier_infiltration

    # multiplier for outdoor air
    multiplier_ventilation = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("multiplier_ventilation", true)
    multiplier_ventilation.setDisplayName("Ventilation Multiplier")
    multiplier_ventilation.setDescription("For each space type multiply the default infiltration value by this.")
    multiplier_ventilation.setDefaultValue(1.0)
    args << multiplier_ventilation

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    args  = OsLib_HelperMethods.createRunVariables(runner, model,user_arguments, arguments(model))
    if !args then return false end

    # check values expected to be non-negative
    non_neg_check = OsLib_HelperMethods.checkDoubleAndIntegerArguments(runner, user_arguments,{"min"=>0.0,"min_eq_bool"=>true,"arg_array" =>["multiplier_occ","multiplier_infiltration","multiplier_ventilation"]})

    # return false if any errors fail
    if !non_neg_check then return false end

    altered_people_definitions = {} # key is def, value is new value
    altered_infiltration_objects = {}# key is def, value is new value
    altered_outdoor_air_objects = {}# key is def, value is new value

    # report initial condition of model
    space_types = model.getSpaceTypes
    runner.registerInitialCondition("The building #{space_types.size} space types.")

    # loop through space types
    space_types.each do |space_type|

      # modify occupancy
      space_type.people.each do |people_inst|

        # get and alter definition
        people_def = people_inst.peopleDefinition
        next if altered_people_definitions[people_def]
        if people_def.peopleperSpaceFloorArea.is_initialized
          people_def.setPeopleperSpaceFloorArea(people_def.peopleperSpaceFloorArea.get * args["multiplier_occ"])
        end

        # update hash
        altered_people_definitions[people_def] = people_def.peopleperSpaceFloorArea

      end

      # modify infiltration
      space_type.spaceInfiltrationDesignFlowRates.each do |infiltration|
        next if altered_infiltration_objects[infiltration]
        if infiltration.flowperExteriorSurfaceArea.is_initialized
          infiltration.setFlowperExteriorSurfaceArea(infiltration.flowperExteriorSurfaceArea.get * args["multiplier_infiltration"])
        end
        if infiltration.airChangesperHour.is_initialized
          infiltration.setAirChangesperHour(infiltration.airChangesperHour.get * args["multiplier_infiltration"])
        end

        # add to hash
        altered_infiltration_objects[infiltration] = [infiltration.flowperExteriorSurfaceArea,infiltration.airChangesperHour]
      end

      # modify outdoor air
      if space_type.designSpecificationOutdoorAir.is_initialized
        outdoor_air = space_type.designSpecificationOutdoorAir.get

        # alter values if not already done
        next if altered_outdoor_air_objects[outdoor_air]
        outdoor_air.setOutdoorAirFlowperPerson(outdoor_air.outdoorAirFlowperPerson * args["multiplier_ventilation"])
        outdoor_air.setOutdoorAirFlowperFloorArea(outdoor_air.outdoorAirFlowperFloorArea * args["multiplier_ventilation"])
        outdoor_air.setOutdoorAirFlowAirChangesperHour(outdoor_air.outdoorAirFlowAirChangesperHour * args["multiplier_ventilation"])

        # add to hash
        altered_outdoor_air_objects[outdoor_air] = [outdoor_air.outdoorAirFlowperPerson,outdoor_air.outdoorAirFlowperFloorArea,outdoor_air.outdoorAirFlowAirChangesperHour]
      end

    end

    # na if nothing in model to look at
    if altered_people_definitions.size + altered_people_definitions.size + altered_people_definitions.size == 0
      runner.registerAsNotApplicable("No objects to alter were found in the model")
      return true
    end

    # report final condition of model
    runner.registerFinalCondition("#{altered_people_definitions.size} people objects were altered. #{altered_infiltration_objects.size} infiltration objects were altered. #{altered_outdoor_air_objects.size} ventilation objects were altered.")

    return true

  end

end

# register the measure to be used by the application
GeneralSpaceTypeCalibrationMeasure.new.registerWithApplication
