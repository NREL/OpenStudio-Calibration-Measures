# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class SetOccupancy < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Set Occupancy"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # the name of the space to add to the model
    zone_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("zone_name", true)
    zone_name.setDisplayName("Zone Name")
    zone_name.setDescription("Zone Name")
    zone_name.setDefaultValue("Seatorium Zone")
    args << zone_name
    
    # calculation_method
    calculation_method_chs = OpenStudio::StringVector.new
    calculation_method_chs << "People"
    calculation_method_chs << "People/Area"
    calculation_method_chs << "Area/People"
    calculation_method = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('calculation_method', calculation_method_chs, true)
    calculation_method.setDisplayName("Calculation Method")
    calculation_method.setDescription("Calculation Method.")
    calculation_method.setDefaultValue("People")
    args << calculation_method
    
    # people value
    people_value = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("people_value", true)
    people_value.setDisplayName("People Value")
    people_value.setDescription("People Value.")
    people_value.setDefaultValue(20)
    args << people_value

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      runner.registerError("Arguments not good")
      return false
    end

    # assign the user inputs to variables
    zone_name = runner.getStringArgumentValue("zone_name", user_arguments)
    calculation_method = runner.getStringArgumentValue("calculation_method", user_arguments)
    people_value = runner.getDoubleArgumentValue("people_value", user_arguments)
    
    # check the zone_name for reasonableness
    if zone_name.empty?
      runner.registerError("Empty space name was entered.")
      return false
    end
    # check the people_value for reasonableness
    if people_value < 0
      runner.registerError("People must be non-negative")
      return false
    end
    
    model.getSpaceTypes.each do |space_type|
      if space_type.name.get == zone_name
        runner.registerInfo("Found Space: #{space_type.name.get} with area #{space_type.floorArea}")
        num_people_obj = space_type.people.size
        if num_people_obj > 1
          runner.registerWarning("Number of People objects in Space is greater than 1")
        end
        floor_area = space_type.floorArea
        if floor_area <= 0
          runner.registerError("Floor Area is 0")
          return false
        end  
        runner.registerInfo("Number of people objects: #{num_people_obj}")

        calculation_method_orig = space_type.people[0].peopleDefinition.numberofPeopleCalculationMethod
        runner.registerInitialCondition("PeopleCalculationMethod is #{calculation_method_orig}")
        runner.registerInfo("Changing PeopleCalculationMethod from #{calculation_method_orig} to #{calculation_method}")
        if calculation_method == "People"
          #set number of people
          if space_type.people[0].peopleDefinition.numberofPeople.is_initialized
            value_orig = space_type.people[0].peopleDefinition.numberofPeople.get
          else
            value_orig = nil
          end
          space_type.people[0].peopleDefinition.setNumberofPeople(people_value)
          value_new = space_type.people[0].peopleDefinition.numberofPeople.get
          runner.registerInfo("Changing number of people FROM: #{value_orig} TO: #{value_new}")
        elsif calculation_method == "People/Area" 
          #set number of people per area
          if space_type.people[0].peopleDefinition.peopleperSpaceFloorArea.is_initialized
            value_orig = space_type.people[0].peopleDefinition.peopleperSpaceFloorArea.get
          else
            value_orig = nil
          end        
          space_type.people[0].peopleDefinition.setPeopleperSpaceFloorArea(people_value/floor_area)
          value_new = space_type.people[0].peopleDefinition.peopleperSpaceFloorArea.get
          runner.registerInfo("Changing number of people per area FROM: #{value_orig} TO: #{value_new}")
        elsif calculation_method == "Area/People"
          #set area per number of people
          if space_type.people[0].peopleDefinition.spaceFloorAreaperPerson.is_initialized
            value_orig = space_type.people[0].peopleDefinition.spaceFloorAreaperPerson.get
          else
            value_orig = nil
          end
          space_type.people[0].peopleDefinition.setSpaceFloorAreaperPerson(floor_area/(people_value + 1e-19))
          value_new = space_type.people[0].peopleDefinition.spaceFloorAreaperPerson.get
          runner.registerInfo("Changing area per number of people FROM: #{value_orig} TO: #{value_new}")
        else
          runner.registerError("unknown PeopleCalculationMethod: #{calculation_method}")
          return false
        end
      else
        runner.registerInfo("SpaceType name: #{space_type.name.get} does not match input: #{zone_name}")      
      end
    end

    return true

  end
  
end

# register the measure to be used by the application
SetOccupancy.new.registerWithApplication
