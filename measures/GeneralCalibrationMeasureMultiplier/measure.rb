# start the measure
class GeneralCalibrationMeasureMultiplier < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "General Calibration Measure Multiplier"
  end

  # human readable description
  def description
    return "This is a general purpose measure to calibrate space and space type elements with a Multiplier."
  end

  # human readable description of modeling approach
  def modeler_description
    return "It will be used for calibration of people, infiltration, and outdoor air. User can choose between a SINGLE SpaceType or ALL the SpaceTypes as well as a SINGLE Space or ALL the Spaces."
  end
  
  def change_name(object, perc_change)
    if perc_change != 0
      object.setName("#{object.name.get} + #{perc_change.round(2)} % change")
    end
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
    occ_perc_change.setDisplayName("Percent Change in the default number of people.")
    occ_perc_change.setDescription("Percent Change in the default number of people.")
    occ_perc_change.setDefaultValue(0.0)
    args << occ_perc_change

    # infiltration % change
    infil_perc_change = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("infil_perc_change", true)
    infil_perc_change.setDisplayName("Percent Change in the default infiltration.")
    infil_perc_change.setDescription("Percent Change in the default infiltration.")
    infil_perc_change.setDefaultValue(0.0)
    args << infil_perc_change

    # ventilation % change
    vent_perc_change = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("vent_perc_change", true)
    vent_perc_change.setDisplayName("Percent Change in the default Ventilation.")
    vent_perc_change.setDescription("Percent Change in the default Ventilation.")
    vent_perc_change.setDefaultValue(0.0)
    args << vent_perc_change

    # internalMass % change
    mass_perc_change = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("mass_perc_change", true)
    mass_perc_change.setDisplayName("Percent Change in the default Internal Mass.")
    mass_perc_change.setDescription("Percent Change in the default Internal Mass.")
    mass_perc_change.setDefaultValue(0.0)
    args << mass_perc_change
    
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
    mass_perc_change = runner.getDoubleArgumentValue("mass_perc_change",user_arguments)
    
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
    
    altered_people_definitions = []
    altered_infiltration_objects = []
    altered_outdoor_air_objects = []
    altered_internalmass_objects = []
    
    # report initial condition of model
    runner.registerInitialCondition("Applying Variable % Changes to #{space_types.size} space types and #{spaces.size} spaces.")
    runner.registerInfo("Applying Variable % Changes to #{space_types.size} space types.")

    # loop through space types
    space_types.each do |space_type|

      # modify occupancy
      space_type.people.each do |people_inst|
        # get and alter definition
        people_def = people_inst.peopleDefinition
        if !altered_people_definitions.include? people_def.handle.to_s
          if people_def.peopleperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{occ_perc_change} % Change to #{people_def.name.get} PeopleperSpaceFloorArea.")
            people_def.setPeopleperSpaceFloorArea(people_def.peopleperSpaceFloorArea.get + people_def.peopleperSpaceFloorArea.get * occ_perc_change * 0.01)
            change_name(people_def, occ_perc_change)
          end
          if people_def.numberofPeople.is_initialized
            runner.registerInfo("Applying #{occ_perc_change} % Change to #{people_def.name.get} numberofPeople.")
            people_def.setNumberofPeople(people_def.numberofPeople.get + people_def.numberofPeople.get * occ_perc_change * 0.01)
            change_name(people_def, occ_perc_change)
          end
          if people_def.spaceFloorAreaperPerson.is_initialized
            runner.registerInfo("Applying #{occ_perc_change} % Change to #{people_def.name.get} spaceFloorAreaperPerson.")
            people_def.setSpaceFloorAreaperPerson(people_def.spaceFloorAreaperPerson.get + people_def.spaceFloorAreaperPerson.get * occ_perc_change * 0.01)
            change_name(people_def, occ_perc_change)
          end
          # update hash
          altered_people_definitions << people_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{people_def.name.get}")
        end
      end

      # modify infiltration
      space_type.spaceInfiltrationDesignFlowRates.each do |infiltration|
        if !altered_infiltration_objects.include? infiltration.handle.to_s
          if infiltration.flowperExteriorSurfaceArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} FlowperExteriorSurfaceArea.")
            infiltration.setFlowperExteriorSurfaceArea(infiltration.flowperExteriorSurfaceArea.get + infiltration.flowperExteriorSurfaceArea.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end
          if infiltration.airChangesperHour.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} AirChangesperHour.")
            infiltration.setAirChangesperHour(infiltration.airChangesperHour.get + infiltration.airChangesperHour.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end    
          if infiltration.designFlowRate.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} designFlowRate.")
            infiltration.setDesignFlowRate(infiltration.designFlowRate.get + infiltration.designFlowRate.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end 
          if infiltration.flowperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} flowperSpaceFloorArea.")
            infiltration.setFlowperSpaceFloorArea(infiltration.flowperSpaceFloorArea.get + infiltration.flowperSpaceFloorArea.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end  
          if infiltration.flowperExteriorWallArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} flowperExteriorWallArea.")
            infiltration.setFlowperExteriorWallArea(infiltration.flowperExteriorWallArea.get + infiltration.flowperExteriorWallArea.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end           
          # add to hash
          altered_infiltration_objects << infiltration.handle.to_s
        else
          runner.registerInfo("Skipping change to #{infiltration.name.get}")  
        end
      end

      # modify outdoor air
      if space_type.designSpecificationOutdoorAir.is_initialized
        outdoor_air = space_type.designSpecificationOutdoorAir.get
        # alter values if not already done
        if !altered_outdoor_air_objects.include? outdoor_air.handle.to_s
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperPerson.")
          outdoor_air.setOutdoorAirFlowperPerson(outdoor_air.outdoorAirFlowperPerson + outdoor_air.outdoorAirFlowperPerson * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperFloorArea.")
          outdoor_air.setOutdoorAirFlowperFloorArea(outdoor_air.outdoorAirFlowperFloorArea + outdoor_air.outdoorAirFlowperFloorArea * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowAirChangesperHour.")
          outdoor_air.setOutdoorAirFlowAirChangesperHour(outdoor_air.outdoorAirFlowAirChangesperHour + outdoor_air.outdoorAirFlowAirChangesperHour * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowRate.")
          outdoor_air.setOutdoorAirFlowRate(outdoor_air.outdoorAirFlowRate + outdoor_air.outdoorAirFlowRate * vent_perc_change * 0.01)
          change_name(outdoor_air, vent_perc_change)
          # add to hash
          altered_outdoor_air_objects << outdoor_air.handle.to_s
        else
          runner.registerInfo("Skipping change to #{outdoor_air.name.get}")  
        end
      end
      
      # modify internal mass
      space_type.internalMass.each do |internalmass|
        # get and alter definition
        internalmass_def = internalmass.internalMassDefinition
        if !altered_internalmass_objects.include? internalmass_def.handle.to_s
          if internalmass_def.surfaceAreaperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceAreaperSpaceFloorArea.")
            internalmass_def.setSurfaceAreaperSpaceFloorArea(internalmass_def.surfaceAreaperSpaceFloorArea.get + internalmass_def.surfaceAreaperSpaceFloorArea.get * mass_perc_change * 0.01)
            change_name(internalmass_def, mass_perc_change)
          end
          if internalmass_def.surfaceArea.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceArea.")
            internalmass_def.setSurfaceArea(internalmass_def.surfaceArea.get + internalmass_def.surfaceArea.get * mass_perc_change * 0.01)
            change_name(internalmass_def, mass_perc_change)
          end
          if internalmass_def.surfaceAreaperPerson.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceAreaperPerson.")
            internalmass_def.setSurfaceAreaperPerson(internalmass_def.surfaceAreaperPerson.get + internalmass_def.surfaceAreaperPerson.get * mass_perc_change * 0.01)
            change_name(internalmass_def, mass_perc_change)
          end
          # update hash
          altered_internalmass_objects << internalmass_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{internalmass_def.name.get}")  
        end
      end
    end #end space_type loop
        
    runner.registerInfo("altered_people_definitions: #{altered_people_definitions}")
    runner.registerInfo("altered_infiltration_objects: #{altered_infiltration_objects}")
    runner.registerInfo("altered_outdoor_air_objects: #{altered_outdoor_air_objects}")
    runner.registerInfo("altered_internalmass_objects: #{altered_internalmass_objects}")    
    
    # report initial condition of model
    runner.registerInfo("Applying Variable % Changes to #{spaces.size} spaces.")

    # loop through space types
    spaces.each do |space|
      # modify occupancy
      space.people.each do |people_inst|
        # get and alter definition
        people_def = people_inst.peopleDefinition
        if !altered_people_definitions.include? people_def.handle.to_s
          if people_def.peopleperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{occ_perc_change} % Change to #{people_def.name.get} PeopleperSpaceFloorArea.")
            people_def.setPeopleperSpaceFloorArea(people_def.peopleperSpaceFloorArea.get + people_def.peopleperSpaceFloorArea.get * occ_perc_change * 0.01)
            change_name(people_def, occ_perc_change)
          end
          if people_def.numberofPeople.is_initialized
            runner.registerInfo("Applying #{occ_perc_change} % Change to #{people_def.name.get} numberofPeople.")
            people_def.setNumberofPeople(people_def.numberofPeople.get + people_def.numberofPeople.get * occ_perc_change * 0.01)
            change_name(people_def, occ_perc_change)
          end
          if people_def.spaceFloorAreaperPerson.is_initialized
            runner.registerInfo("Applying #{occ_perc_change} % Change to #{people_def.name.get} spaceFloorAreaperPerson.")
            people_def.setSpaceFloorAreaperPerson(people_def.spaceFloorAreaperPerson.get + people_def.spaceFloorAreaperPerson.get * occ_perc_change * 0.01)
            change_name(people_def, occ_perc_change)
          end
          # update hash
          altered_people_definitions << people_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{people_def.name.get}")  
        end
      end

      # modify infiltration
      space.spaceInfiltrationDesignFlowRates.each do |infiltration|
        if !altered_infiltration_objects.include? infiltration.handle.to_s
          if infiltration.flowperExteriorSurfaceArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} FlowperExteriorSurfaceArea.")
            infiltration.setFlowperExteriorSurfaceArea(infiltration.flowperExteriorSurfaceArea.get + infiltration.flowperExteriorSurfaceArea.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end
          if infiltration.airChangesperHour.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} AirChangesperHour.")
            infiltration.setAirChangesperHour(infiltration.airChangesperHour.get + infiltration.airChangesperHour.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end
          if infiltration.designFlowRate.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} designFlowRate.")
            infiltration.setDesignFlowRate(infiltration.designFlowRate.get + infiltration.designFlowRate.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end 
          if infiltration.flowperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} flowperSpaceFloorArea.")
            infiltration.setFlowperSpaceFloorArea(infiltration.flowperSpaceFloorArea.get + infiltration.flowperSpaceFloorArea.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end  
          if infiltration.flowperExteriorWallArea.is_initialized
            runner.registerInfo("Applying #{infil_perc_change} % Change to #{infiltration.name.get} flowperExteriorWallArea.")
            infiltration.setFlowperExteriorWallArea(infiltration.flowperExteriorWallArea.get + infiltration.flowperExteriorWallArea.get * infil_perc_change * 0.01)
            change_name(infiltration, infil_perc_change)
          end          
          # add to hash
          altered_infiltration_objects << infiltration.handle.to_s
        else
          runner.registerInfo("Skipping change to #{infiltration.name.get}")  
        end
      end

      # modify outdoor air
      if space.designSpecificationOutdoorAir.is_initialized
        outdoor_air = space.designSpecificationOutdoorAir.get
        # alter values if not already done
        if !altered_outdoor_air_objects.include? outdoor_air.handle.to_s
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperPerson.")
          outdoor_air.setOutdoorAirFlowperPerson(outdoor_air.outdoorAirFlowperPerson + outdoor_air.outdoorAirFlowperPerson * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowperFloorArea.")
          outdoor_air.setOutdoorAirFlowperFloorArea(outdoor_air.outdoorAirFlowperFloorArea + outdoor_air.outdoorAirFlowperFloorArea * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowAirChangesperHour.")
          outdoor_air.setOutdoorAirFlowAirChangesperHour(outdoor_air.outdoorAirFlowAirChangesperHour + outdoor_air.outdoorAirFlowAirChangesperHour * vent_perc_change * 0.01)
          runner.registerInfo("Applying #{vent_perc_change} % Change to #{outdoor_air.name.get} OutdoorAirFlowRate.")
          outdoor_air.setOutdoorAirFlowRate(outdoor_air.outdoorAirFlowRate + outdoor_air.outdoorAirFlowRate * vent_perc_change * 0.01)
          change_name(outdoor_air, vent_perc_change) 
          # add to hash
          altered_outdoor_air_objects << outdoor_air.handle.to_s
        else
          runner.registerInfo("Skipping change to #{outdoor_air.name.get}")  
        end
      end
      
      # modify internal mass
      space.internalMass.each do |internalmass|
        # get and alter definition
        internalmass_def = internalmass.internalMassDefinition
        if !altered_internalmass_objects.include? internalmass_def.handle.to_s
          if internalmass_def.surfaceAreaperSpaceFloorArea.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceAreaperSpaceFloorArea.")
            internalmass_def.setSurfaceAreaperSpaceFloorArea(internalmass_def.surfaceAreaperSpaceFloorArea.get + internalmass_def.surfaceAreaperSpaceFloorArea.get * mass_perc_change * 0.01)
            change_name(internalmass_def, mass_perc_change)
          end
          if internalmass_def.surfaceArea.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceArea.")
            internalmass_def.setSurfaceArea(internalmass_def.surfaceArea.get + internalmass_def.surfaceArea.get * mass_perc_change * 0.01)
            change_name(internalmass_def, mass_perc_change)
          end
          if internalmass_def.surfaceAreaperPerson.is_initialized
            runner.registerInfo("Applying #{mass_perc_change} % Change to #{internalmass_def.name.get} surfaceAreaperPerson.")
            internalmass_def.setSurfaceAreaperPerson(internalmass_def.surfaceAreaperPerson.get + internalmass_def.surfaceAreaperPerson.get * mass_perc_change * 0.01)
            change_name(internalmass_def, mass_perc_change)
          end 
          # update hash
          altered_internalmass_objects << internalmass_def.handle.to_s
        else
          runner.registerInfo("Skipping change to #{internalmass_def.name.get}")  
        end
      end
    end #end spaces loop
    
    runner.registerInfo("altered_people_definitions: #{altered_people_definitions}")
    runner.registerInfo("altered_infiltration_objects: #{altered_infiltration_objects}")
    runner.registerInfo("altered_outdoor_air_objects: #{altered_outdoor_air_objects}")
    runner.registerInfo("altered_internalmass_objects: #{altered_internalmass_objects}")    
    
    
    # na if nothing in model to look at
    if altered_people_definitions.size + altered_people_definitions.size + altered_people_definitions.size + altered_internalmass_objects.size == 0
      runner.registerAsNotApplicable("No objects to alter were found in the model")
      return true
    end

    # report final condition of model
    runner.registerFinalCondition("#{altered_people_definitions.size} people objects were altered. #{altered_infiltration_objects.size} infiltration objects were altered. #{altered_outdoor_air_objects.size} ventilation objects were altered. #{altered_internalmass_objects.size} internal mass objects were altered.")

    return true

  end

end

# register the measure to be used by the application
GeneralCalibrationMeasureMultiplier.new.registerWithApplication
