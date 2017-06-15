# start the measure
class GeneralCalibrationMeasure < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "General Calibration Measure"
  end

  # human readable description
  def description
    return "This is a general purpose measure to calibrate space and space type elements."
  end

  # human readable description of modeling approach
  def modeler_description
    return "It will be used for calibration of people, infiltration, and outdoor air."
  end
  
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a choice argument for model objects
    space_type_handles = OpenStudio::StringVector.new
    space_type_display_names = OpenStudio::StringVector.new

    #putting model object and names into hash
    space_type_args = model.getSpaceTypes
    space_type_args_hash = {}
    space_type_args.each do |space_type_arg|
      space_type_args_hash[space_type_arg.name.to_s] = space_type_arg
    end

    #looping through sorted hash of model objects
    space_type_args_hash.sort.map do |key,value|
      #only include if space type is used in the model
      if value.spaces.size > 0
        space_type_handles << value.handle.to_s
        space_type_display_names << key
      end
    end

    #add building to string vector with space type
    building = model.getBuilding
    space_type_handles << building.handle.to_s
    space_type_display_names << "*Entire Building*"
    space_type_handles << "0"
    space_type_display_names << "*None*"

    #make a choice argument for space type
    space_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("space_type", space_type_handles, space_type_display_names)
    space_type.setDisplayName("Apply the Measure to a Specific Space Type or to the Entire Model.")
    space_type.setDefaultValue("*Entire Building*") #if no space type is chosen this will run on the entire building
    args << space_type
    
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
    object = runner.getOptionalWorkspaceObjectChoiceValue("space_type",user_arguments,model)
    multiplier_occ = runner.getDoubleArgumentValue("multiplier_occ",user_arguments)
    multiplier_infiltration = runner.getDoubleArgumentValue("multiplier_infiltration",user_arguments)
    multiplier_ventilation = runner.getDoubleArgumentValue("multiplier_ventilation",user_arguments)
        
    #check the space_type for reasonableness and see if measure should run on space type or on the entire building
    apply_to_building = false
    apply_to_spaces = false
    space_types = []
    spaces = []
    space_type = nil
    if object.empty?
      runner.registerInfo("space_type is empty")
      #handle = runner.getStringArgumentValue("space_type",user_arguments)
      #if handle.empty?
      #  runner.registerError("No space type was chosen.")
      #else
      #  runner.registerError("The selected space type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      #end
      #return false
    else
      if not object.get.to_SpaceType.empty?
        space_type = object.get.to_SpaceType.get
      elsif not object.get.to_Building.empty?
        apply_to_building = true
      else
        runner.registerError("Script Error - argument not showing up as space type or building.")
        return false
      end
    end
    
    altered_people_definitions = {} # key is def, value is new value
    altered_infiltration_objects = {}# key is def, value is new value
    altered_outdoor_air_objects = {}# key is def, value is new value

    #get space types to apply changes to
    if apply_to_building
      space_types = model.getSpaceTypes
    else
      space_types = []
      space_types << space_type #only run on a single space type
    end

    #get spaces in model
    # if apply_to_spaces
      # spaces = model.getSpaces
    # else
      # if not space_type.spaces.empty?
        # spaces = space_type.spaces #only run on a single space type
      # end
    # end
    
    # report initial condition of model
    runner.registerInitialCondition("Applying Variable % Changes to #{space_types.size} space types and #{spaces.size} spaces.")
    runner.registerInfo("Applying Variable % Changes to #{space_types.size} space types.")

    # loop through space types
    space_types.each do |space_type|

      # modify occupancy
      space_type.people.each do |people_inst|

        # get and alter definition
        people_def = people_inst.peopleDefinition
        next if altered_people_definitions[people_def]
        if people_def.peopleperSpaceFloorArea.is_initialized
          people_def.setPeopleperSpaceFloorArea(people_def.peopleperSpaceFloorArea.get * multiplier_occ)
        end

        # update hash
        altered_people_definitions[people_def] = people_def.peopleperSpaceFloorArea

      end

      # modify infiltration
      space_type.spaceInfiltrationDesignFlowRates.each do |infiltration|
        next if altered_infiltration_objects[infiltration]
        if infiltration.flowperExteriorSurfaceArea.is_initialized
          infiltration.setFlowperExteriorSurfaceArea(infiltration.flowperExteriorSurfaceArea.get * multiplier_infiltration)
        end
        if infiltration.airChangesperHour.is_initialized
          infiltration.setAirChangesperHour(infiltration.airChangesperHour.get * multiplier_infiltration)
        end

        # add to hash
        altered_infiltration_objects[infiltration] = [infiltration.flowperExteriorSurfaceArea,infiltration.airChangesperHour]
      end

      # modify outdoor air
      if space_type.designSpecificationOutdoorAir.is_initialized
        outdoor_air = space_type.designSpecificationOutdoorAir.get

        # alter values if not already done
        next if altered_outdoor_air_objects[outdoor_air]
        outdoor_air.setOutdoorAirFlowperPerson(outdoor_air.outdoorAirFlowperPerson * multiplier_ventilation)
        outdoor_air.setOutdoorAirFlowperFloorArea(outdoor_air.outdoorAirFlowperFloorArea * multiplier_ventilation)
        outdoor_air.setOutdoorAirFlowAirChangesperHour(outdoor_air.outdoorAirFlowAirChangesperHour * multiplier_ventilation)

        # add to hash
        altered_outdoor_air_objects[outdoor_air] = [outdoor_air.outdoorAirFlowperPerson,outdoor_air.outdoorAirFlowperFloorArea,outdoor_air.outdoorAirFlowAirChangesperHour]
      end

    end #end space_type loop
    
    # report initial condition of model
    runner.registerInfo("Applying Variable % Changes to #{spaces.size} spaces.")

    # loop through space types
    spaces.each do |space|

      # modify occupancy
      space.people.each do |people_inst|

        # get and alter definition
        people_def = people_inst.peopleDefinition
        next if altered_people_definitions[people_def]
        if people_def.peopleperSpaceFloorArea.is_initialized
          people_def.setPeopleperSpaceFloorArea(people_def.peopleperSpaceFloorArea.get * multiplier_occ)
        end

        # update hash
        altered_people_definitions[people_def] = people_def.peopleperSpaceFloorArea

      end

      # modify infiltration
      space.spaceInfiltrationDesignFlowRates.each do |infiltration|
        next if altered_infiltration_objects[infiltration]
        if infiltration.flowperExteriorSurfaceArea.is_initialized
          infiltration.setFlowperExteriorSurfaceArea(infiltration.flowperExteriorSurfaceArea.get * multiplier_infiltration)
        end
        if infiltration.airChangesperHour.is_initialized
          infiltration.setAirChangesperHour(infiltration.airChangesperHour.get * multiplier_infiltration)
        end

        # add to hash
        altered_infiltration_objects[infiltration] = [infiltration.flowperExteriorSurfaceArea,infiltration.airChangesperHour]
      end

      # modify outdoor air
      if space.designSpecificationOutdoorAir.is_initialized
        outdoor_air = space.designSpecificationOutdoorAir.get

        # alter values if not already done
        next if altered_outdoor_air_objects[outdoor_air]
        outdoor_air.setOutdoorAirFlowperPerson(outdoor_air.outdoorAirFlowperPerson * multiplier_ventilation)
        outdoor_air.setOutdoorAirFlowperFloorArea(outdoor_air.outdoorAirFlowperFloorArea * multiplier_ventilation)
        outdoor_air.setOutdoorAirFlowAirChangesperHour(outdoor_air.outdoorAirFlowAirChangesperHour * multiplier_ventilation)

        # add to hash
        altered_outdoor_air_objects[outdoor_air] = [outdoor_air.outdoorAirFlowperPerson,outdoor_air.outdoorAirFlowperFloorArea,outdoor_air.outdoorAirFlowAirChangesperHour]
      end

    end #end spaces loop
    
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
GeneralCalibrationMeasure.new.registerWithApplication
