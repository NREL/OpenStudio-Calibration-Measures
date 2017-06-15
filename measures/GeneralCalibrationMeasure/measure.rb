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
    return "It will be used for calibration of people, infiltration, and outdoor air. User can choose between a SINGLE SpaceType or ALL the SpaceTypes as well as a SINGLE Space or ALL the Spaces."
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
    space_type_display_names << "*All SpaceTypes*"
    space_type_handles << "0"
    space_type_display_names << "*None*"

    #make a choice argument for space type
    space_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("space_type", space_type_handles, space_type_display_names)
    space_type.setDisplayName("Apply the Measure to a SINGLE SpaceType, ALL the SpaceTypes or NONE.")
    space_type.setDefaultValue("*All SpaceTypes*") #if no space type is chosen this will run on the entire building
    args << space_type
  
    #make a choice argument for model objects
    space_handles = OpenStudio::StringVector.new
    space_display_names = OpenStudio::StringVector.new

    #putting model object and names into hash
    space_args = model.getSpaces
    space_args_hash = {}
    space_args.each do |space_arg|
      space_args_hash[space_arg.name.to_s] = space_arg
    end

    #looping through sorted hash of model objects
    space_args_hash.sort.map do |key,value|
      space_handles << value.handle.to_s
      space_display_names << key
    end

    #add building to string vector with spaces
    building = model.getBuilding
    space_handles << building.handle.to_s
    space_display_names << "*All Spaces*"
    space_handles << "0"
    space_display_names << "*None*"

    #make a choice argument for space type
    space = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("space", space_handles, space_display_names)
    space.setDisplayName("Apply the Measure to a SINGLE Space, ALL the Spaces or NONE.")
    space.setDefaultValue("*All Spaces*") #if no space type is chosen this will run on the entire building
    args << space
    
    # occupancy % change
    occ_perc_change = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("occ_perc_change", true)
    occ_perc_change.setDisplayName("Occupancy Multiplier")
    occ_perc_change.setDescription("Percent Change in the default number of people by this value.")
    occ_perc_change.setDefaultValue(0.0)
    args << occ_perc_change

    # infiltration % change
    infil_perc_change = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("infil_perc_change", true)
    infil_perc_change.setDisplayName("Infiltration Multiplier")
    infil_perc_change.setDescription("Percent Change in the default infiltration value by this.")
    infil_perc_change.setDefaultValue(0.0)
    args << infil_perc_change

    # ventilation % change
    vent_perc_change = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("vent_perc_change", true)
    vent_perc_change.setDisplayName("Ventilation Multiplier")
    vent_perc_change.setDescription("Percent Change in the default Ventilation value by this.")
    vent_perc_change.setDefaultValue(0.0)
    args << vent_perc_change

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    space_type_object = runner.getOptionalWorkspaceObjectChoiceValue("space_type",user_arguments,model)
    space_type_handle = runner.getStringArgumentValue("space_type",user_arguments)
    space_object = runner.getOptionalWorkspaceObjectChoiceValue("space",user_arguments,model)
    space_handle = runner.getStringArgumentValue("space",user_arguments)
    occ_perc_change = runner.getDoubleArgumentValue("occ_perc_change",user_arguments)
    infil_perc_change = runner.getDoubleArgumentValue("infil_perc_change",user_arguments)
    vent_perc_change = runner.getDoubleArgumentValue("vent_perc_change",user_arguments)
        
    #find objects to change
    space_types = []
    spaces = []
    building = model.getBuilding
    building_handle = building.handle.to_s
    runner.registerInfo("space_type_handle: #{space_type_handle}")
    runner.registerInfo("space_handle: #{space_handle}")
    #setup space_types
    if space_type_handle == building_handle
      #Use ALL SpaceTypes
      runner.registerInfo("Applying change to ALL SpaceTypes")
      space_types = model.getSpaceTypes
    elsif space_type_handle == 0.to_s
      #SpaceTypes set to NONE so do nothing
      runner.registerInfo("Applying change to NONE SpaceTypes")
    elsif not space_type_handle.empty?
      #Single SpaceType handle found, check if object is good    
      if not space_type_object.get.to_SpaceType.empty?
      runner.registerInfo("Applying change to #{space_type_object.get.name.to_s} SpaceType")
        space_types << space_type_object.get.to_SpaceType.get
      else
        runner.registerError("SpaceType with handle #{space_type_handle} could not be found.")
      end
    else
      runner.registerError("SpaceType handle is empty.")
      return false
    end
    
    #setup spaces
    if space_handle == building_handle
      #Use ALL Spaces
      runner.registerInfo("Applying change to ALL Spaces")
      spaces = model.getSpaces
    elsif space_handle == 0.to_s
      #Spaces set to NONE so do nothing
      runner.registerInfo("Applying change to NONE Spaces")
    elsif not space_handle.empty?
      #Single Space handle found, check if object is good    
      if not space_object.get.to_Space.empty?
      runner.registerInfo("Applying change to #{space_object.get.name.to_s} Space")
        spaces << space_object.get.to_Space.get
      else
        runner.registerError("Space with handle #{space_handle} could not be found.")
      end
    else
      runner.registerError("Space handle is empty.")
      return false
    end
    
    altered_people_definitions = {} # key is def, value is new value
    altered_infiltration_objects = {}# key is def, value is new value
    altered_outdoor_air_objects = {}# key is def, value is new value
    
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
          runner.registerInfo("Applying #{occ_perc_change} % Change to #{people_def.name.get} PeopleperSpaceFloorArea.")
          people_def.setPeopleperSpaceFloorArea(people_def.peopleperSpaceFloorArea.get + people_def.peopleperSpaceFloorArea.get * occ_perc_change * 0.01)
        end
        # update hash
        altered_people_definitions[people_def] = people_def.peopleperSpaceFloorArea
      end

      # modify infiltration
      space_type.spaceInfiltrationDesignFlowRates.each do |infiltration|
        next if altered_infiltration_objects[infiltration]
        if infiltration.flowperExteriorSurfaceArea.is_initialized
          runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} FlowperExteriorSurfaceArea.")
          infiltration.setFlowperExteriorSurfaceArea(infiltration.flowperExteriorSurfaceArea.get + infiltration.flowperExteriorSurfaceArea.get * infil_perc_change * 0.01)
        end
        if infiltration.airChangesperHour.is_initialized
          runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} AirChangesperHour.")
          infiltration.setAirChangesperHour(infiltration.airChangesperHour.get + infiltration.airChangesperHour.get * infil_perc_change * 0.01)
        end
        # add to hash
        altered_infiltration_objects[infiltration] = [infiltration.flowperExteriorSurfaceArea,infiltration.airChangesperHour]
      end

      # modify outdoor air
      if space_type.designSpecificationOutdoorAir.is_initialized
        outdoor_air = space_type.designSpecificationOutdoorAir.get
        # alter values if not already done
        next if altered_outdoor_air_objects[outdoor_air]
        runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperPerson.")
        outdoor_air.setOutdoorAirFlowperPerson(outdoor_air.outdoorAirFlowperPerson + outdoor_air.outdoorAirFlowperPerson * vent_perc_change * 0.01)
        runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperFloorArea.")
        outdoor_air.setOutdoorAirFlowperFloorArea(outdoor_air.outdoorAirFlowperFloorArea + outdoor_air.outdoorAirFlowperFloorArea * vent_perc_change * 0.01)
        runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowAirChangesperHour.")
        outdoor_air.setOutdoorAirFlowAirChangesperHour(outdoor_air.outdoorAirFlowAirChangesperHour + outdoor_air.outdoorAirFlowAirChangesperHour * vent_perc_change * 0.01)
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
          runner.registerInfo("Applying #{occ_perc_change} % Change to #{people_def.name.get} PeopleperSpaceFloorArea.")
          people_def.setPeopleperSpaceFloorArea(people_def.peopleperSpaceFloorArea.get + people_def.peopleperSpaceFloorArea.get * occ_perc_change * 0.01)
        end
        # update hash
        altered_people_definitions[people_def] = people_def.peopleperSpaceFloorArea
      end

      # modify infiltration
      space.spaceInfiltrationDesignFlowRates.each do |infiltration|
        next if altered_infiltration_objects[infiltration]
        if infiltration.flowperExteriorSurfaceArea.is_initialized
          runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} FlowperExteriorSurfaceArea.")
          infiltration.setFlowperExteriorSurfaceArea(infiltration.flowperExteriorSurfaceArea.get + infiltration.flowperExteriorSurfaceArea.get * infil_perc_change * 0.01)
        end
        if infiltration.airChangesperHour.is_initialized
          runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} AirChangesperHour.")
          infiltration.setAirChangesperHour(infiltration.airChangesperHour.get + infiltration.airChangesperHour.get * infil_perc_change * 0.01)
        end
        # add to hash
        altered_infiltration_objects[infiltration] = [infiltration.flowperExteriorSurfaceArea,infiltration.airChangesperHour]
      end

      # modify outdoor air
      if space.designSpecificationOutdoorAir.is_initialized
        outdoor_air = space.designSpecificationOutdoorAir.get
        # alter values if not already done
        next if altered_outdoor_air_objects[outdoor_air]
        runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperPerson.")
        outdoor_air.setOutdoorAirFlowperPerson(outdoor_air.outdoorAirFlowperPerson + outdoor_air.outdoorAirFlowperPerson * vent_perc_change * 0.01)
        runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperFloorArea.")
        outdoor_air.setOutdoorAirFlowperFloorArea(outdoor_air.outdoorAirFlowperFloorArea + outdoor_air.outdoorAirFlowperFloorArea * vent_perc_change * 0.01)
        runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowAirChangesperHour.")
        outdoor_air.setOutdoorAirFlowAirChangesperHour(outdoor_air.outdoorAirFlowAirChangesperHour + outdoor_air.outdoorAirFlowAirChangesperHour * vent_perc_change * 0.01)
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
