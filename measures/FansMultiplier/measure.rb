# start the measure
class FansMultiplier < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Fans Multiplier"
  end

  # human readable description
  def description
    return "This is a general purpose measure to calibrate Fans with a Multiplier."
  end

  # human readable description of modeling approach
  def modeler_description
    return "It will be used for calibration maximum flow rate, efficiency, pressure rise and motor efficiency. User can choose between a SINGLE Fan or ALL the Fans."
  end
  
  def change_name(object, multiplier)
    if multiplier != 1
      object.setName("#{object.name.get} #{multiplier.round(2)}x Multiplier")
    end
  end
  
  def check_multiplier(runner, multiplier)
    if multiplier < 0
      runner.registerError("Multiplier #{multiplier} cannot be negative.")
      return false
    end
  end
  
  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for constructions that are applied to surfaces in the model
    loop_handles = OpenStudio::StringVector.new
    loop_display_names = OpenStudio::StringVector.new

    #putting air loops and names into hash
    loop_args = model.getAirLoopHVACs
    loop_args_hash = {}
    loop_args.each do |loop_arg|
      loop_args_hash[loop_arg.name.to_s] = loop_arg
    end

    #looping through sorted hash of air loops
    loop_args_hash.sort.map do |key,value|
      show_loop = false
      components = value.supplyComponents
      components.each do |component|
        if not component.to_FanConstantVolume.empty?
          show_loop = true
        end
        if not component.to_FanVariableVolume.empty?
          show_loop = true
        end
        if not component.to_FanOnOff.empty?
          show_loop = true
        end
      end

      #if loop as object of correct type then add to hash.
      if show_loop == true
        loop_handles << value.handle.to_s
        loop_display_names << key
      end
    end

    #add building to string vector with space type
    building = model.getBuilding
    loop_handles << building.handle.to_s
    loop_display_names << "*All Fans*"
    loop_handles << "0"
    loop_display_names << "*None*"

    #make a choice argument for space type
    fan_arg = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("fan", loop_handles, loop_display_names)
    fan_arg.setDisplayName("Apply the Measure to a SINGLE Fan, ALL the Fans or NONE.")
    fan_arg.setDefaultValue("*All Fans*") #if no space type is chosen this will run on the entire building
    args << fan_arg
        
    # Maximum FlowRate multiplier
    max_flowrate_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("max_flowrate_multiplier", true)
    max_flowrate_multiplier.setDisplayName("Multiplier for Maximum FlowRate.")
    max_flowrate_multiplier.setDescription("Multiplier for Maximum FlowRate.")
    max_flowrate_multiplier.setDefaultValue(1.0)
    max_flowrate_multiplier.setMinValue(0.0)
    args << max_flowrate_multiplier
    
    # fan_efficiency_multiplier
    fan_efficiency_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("fan_efficiency_multiplier", true)
    fan_efficiency_multiplier.setDisplayName("Multiplier for Fan Efficiency.")
    fan_efficiency_multiplier.setDescription("Multiplier for Fan Efficiency.")
    fan_efficiency_multiplier.setDefaultValue(1.0)
    args << fan_efficiency_multiplier
    
    # pressure_rise_multiplier
    pressure_rise_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("pressure_rise_multiplier", true)
    pressure_rise_multiplier.setDisplayName("Multiplier for Electric Equipment.")
    pressure_rise_multiplier.setDescription("Multiplier for Electric Equipment.")
    pressure_rise_multiplier.setDefaultValue(1.0)
    args << pressure_rise_multiplier
    
    # motor_efficiency_multiplier
    motor_efficiency_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("motor_efficiency_multiplier", true)
    motor_efficiency_multiplier.setDisplayName("Multiplier for Gas Equipment.")
    motor_efficiency_multiplier.setDescription("Multiplier for Gas Equipment.")
    motor_efficiency_multiplier.setDefaultValue(1.0)
    args << motor_efficiency_multiplier
    
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
    fan_object = runner.getOptionalWorkspaceObjectChoiceValue("fan",user_arguments,model)
    fan_handle = runner.getStringArgumentValue("fan",user_arguments)
    pressure_rise_multiplier = runner.getDoubleArgumentValue("pressure_rise_multiplier",user_arguments)
    check_multiplier(runner, pressure_rise_multiplier)
    motor_efficiency_multiplier = runner.getDoubleArgumentValue("motor_efficiency_multiplier",user_arguments)
    check_multiplier(runner, motor_efficiency_multiplier)
    max_flowrate_multiplier = runner.getDoubleArgumentValue("max_flowrate_multiplier",user_arguments)
    check_multiplier(runner, max_flowrate_multiplier)
    fan_efficiency_multiplier = runner.getDoubleArgumentValue("fan_efficiency_multiplier",user_arguments)
    check_multiplier(runner, fan_efficiency_multiplier)
    
    #find objects to change
    fans = []
    building = model.getBuilding
    building_handle = building.handle.to_s
    runner.registerInfo("fan_handle: #{fan_handle}")
    #setup fans
    if fan_handle == building_handle
      #Use ALL Fans
      runner.registerInfo("Applying change to ALL Fans")
      loops = model.getAirLoopHVACs
      #loop through air loops
      loops.each do |loop|
        supply_components = loop.supplyComponents
        #find fans on loops
        supply_components.each do |supply_component|
          if not supply_component.to_FanConstantVolume.empty?
            fans << supply_component.to_FanConstantVolume.get
          elsif not supply_component.to_FanVariableVolume.empty?
            fans << supply_component.to_FanVariableVolume.get
          elsif not supply_component.to_FanOnOff.empty?
            fans << supply_component.to_FanOnOff.get
          end
        end   
      end      
    elsif fan_handle == 0.to_s
      #Fans set to NONE so do nothing
      runner.registerInfo("Applying change to NONE Fans")
    elsif not fan_handle.empty?
      #Single Fan handle found, check if object is good    
      if not fan_object.get.to_FanConstantVolume.empty?
        runner.registerInfo("Applying change to #{fan_object.get.name.to_s} Fan")
        fans << fan_object.get.to_FanConstantVolume.get
      elsif not fan_object.get.to_FanVariableVolume.empty?
        runner.registerInfo("Applying change to #{fan_object.get.name.to_s} Fan")
        fans << fan_object.get.to_FanVariableVolume.get
      elsif not fan_object.get.to_FanOnOff.empty?
        runner.registerInfo("Applying change to #{fan_object.get.name.to_s} Fan")
        fans << fan_object.get.to_FanOnOff.get
      else
        runner.registerError("Fan with handle #{fan_handle} could not be found.")
      end
    else
      runner.registerError("Fan handle is empty.")
      return false
    end
       
    # report initial condition of model
    runner.registerInitialCondition("Applying Multiplier to #{fans.size} fans.")
    runner.registerInfo("Applying Multiplier to #{fans.size} fans.")

    # loop through fans
    fans.each do |fan|

      # modify max flowrate
      runner.registerInfo("Applying #{max_flowrate_multiplier}x multiplier to #{fan.name.get}.")
      fan.setMaximumFlowRate(max_flowrate_multiplier)          
      # change name
      change_name(fan, max_flowrate_multiplier)

      
      # modify fan_efficiency_multiplier
      runner.registerInfo("Applying #{fan_efficiency_multiplier}x multiplier to #{fan.name.get}.")
      fan.setFanEfficiency(fan_efficiency_multiplier)          
      # change name
      change_name(fan, fan_efficiency_multiplier)

      
      # pressure_rise_multiplier
      runner.registerInfo("Applying #{pressure_rise_multiplier}x multiplier to #{fan.name.get}.")
      fan.setPressureRise(pressure_rise_multiplier)          
      #change name
      change_name(fan, pressure_rise_multiplier)

      
      # motor_efficiency_multiplier
      runner.registerInfo("Applying #{motor_efficiency_multiplier}x multiplier to #{fan.name.get}.")
      fan.setMotorEfficiency(motor_efficiency_multiplier)          
      #change name
      change_name(fan, motor_efficiency_multiplier)

    end #end fan loop
    
    # na if nothing in model to look at
    if fans.size == 0
      runner.registerAsNotApplicable("No objects to alter were found in the model")
      return true
    end

    # report final condition of model
    runner.registerFinalCondition("#{fans.size} fans objects were altered.")

    return true

  end

end

# register the measure to be used by the application
FansMultiplier.new.registerWithApplication
