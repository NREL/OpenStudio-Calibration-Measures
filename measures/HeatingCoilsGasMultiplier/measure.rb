# start the measure
class HeatingCoilsGasMultiplier < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Heating Coils Gas Multiplier"
  end

  # human readable description
  def description
    return "This is a general purpose measure to calibrate Gas Heating Coils with a Multiplier."
  end

  # human readable description of modeling approach
  def modeler_description
    return "It will be used for calibration of rated capacity and efficiency and parasitic loads. User can choose between a SINGLE coil or ALL the Coils."
  end
  
  def change_name(object,coil_parasitic_gas_multiplier,coil_efficiency_multiplier,coil_parasitic_electric_multiplier,coil_capacity_multiplier)
    nameString = "#{object.name.get}"
    if coil_parasitic_gas_multiplier != 1.0
      nameString = nameString + " #{coil_parasitic_gas_multiplier.round(2)}x gasPara"
    end
    if coil_parasitic_electric_multiplier != 1.0
      nameString = nameString + " #{coil_parasitic_electric_multiplier.round(2)}x elecPara"
    end
    if coil_efficiency_multiplier != 1.0
      nameString = nameString + " #{coil_efficiency_multiplier.round(2)}x coilEff"
    end
    if coil_capacity_multiplier != 1.0
      nameString = nameString + " #{coil_capacity_multiplier.round(2)}x coilCap"
    end
    object.setName(nameString)
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
        if not component.to_CoilHeatingGas.empty?
          show_loop = true
          loop_handles << component.handle.to_s
          loop_display_names << component.name.to_s
        end
      end

      #if loop as object of correct type then add to hash.
      # if show_loop == true
        # loop_handles << value.handle.to_s
        # loop_display_names << key
      # end
    end

    #add building to string vector with space type
    building = model.getBuilding
    loop_handles << building.handle.to_s
    loop_display_names << "*All Gas Heating Coils*"
    loop_handles << "0"
    loop_display_names << "*None*"

    #make a choice argument for space type
    coil_arg = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("coil", loop_handles, loop_display_names)
    coil_arg.setDisplayName("Apply the Measure to a SINGLE Gas Heating Coil, ALL the Gas Heating Coils or NONE.")
    coil_arg.setDefaultValue("*All Gas Heating Coils*") #if no space type is chosen this will run on the entire building
    args << coil_arg
    
    # coil_efficiency_multiplier
    coil_efficiency_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("coil_efficiency_multiplier", true)
    coil_efficiency_multiplier.setDisplayName("Multiplier for coil Efficiency.")
    coil_efficiency_multiplier.setDescription("Multiplier for coil Efficiency.")
    coil_efficiency_multiplier.setDefaultValue(1.0)
    args << coil_efficiency_multiplier
    
    # coil_capacity_multiplier
    coil_capacity_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("coil_capacity_multiplier", true)
    coil_capacity_multiplier.setDisplayName("Multiplier for coil Capacity.")
    coil_capacity_multiplier.setDescription("Multiplier for coil Capacity.")
    coil_capacity_multiplier.setDefaultValue(1.0)
    args << coil_capacity_multiplier    
    
     # coil_parasitic_electric_multiplier
    coil_parasitic_electric_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("coil_parasitic_electric_multiplier", true)
    coil_parasitic_electric_multiplier.setDisplayName("Multiplier for coil parasitic electric load.")
    coil_parasitic_electric_multiplier.setDescription("Multiplier for coil parasitic electric load.")
    coil_parasitic_electric_multiplier.setDefaultValue(1.0)
    args << coil_parasitic_electric_multiplier      
    
    # coil_parasitic_gas_multiplier
    coil_parasitic_gas_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("coil_parasitic_gas_multiplier", true)
    coil_parasitic_gas_multiplier.setDisplayName("Multiplier for coil parasitic gas load.")
    coil_parasitic_gas_multiplier.setDescription("Multiplier for coil parasitic gas load.")
    coil_parasitic_gas_multiplier.setDefaultValue(1.0)
    args << coil_parasitic_gas_multiplier  
    
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
    coil_object = runner.getOptionalWorkspaceObjectChoiceValue("coil",user_arguments,model)
    coil_handle = runner.getStringArgumentValue("coil",user_arguments)

    coil_capacity_multiplier = runner.getDoubleArgumentValue("coil_capacity_multiplier",user_arguments)
    check_multiplier(runner, coil_capacity_multiplier)
    coil_efficiency_multiplier = runner.getDoubleArgumentValue("coil_efficiency_multiplier",user_arguments)
    check_multiplier(runner, coil_efficiency_multiplier)
    coil_parasitic_electric_multiplier = runner.getDoubleArgumentValue("coil_parasitic_electric_multiplier",user_arguments)
    check_multiplier(runner, coil_parasitic_electric_multiplier)
    coil_parasitic_gas_multiplier = runner.getDoubleArgumentValue("coil_parasitic_gas_multiplier",user_arguments)
    check_multiplier(runner, coil_parasitic_gas_multiplier)
    
    #find objects to change
    coils = []
    building = model.getBuilding
    building_handle = building.handle.to_s
    runner.registerInfo("coil_handle: #{coil_handle}")
    #setup coils
    if coil_handle == building_handle
      #Use ALL coils
      runner.registerInfo("Applying change to ALL Coils")
      loops = model.getAirLoopHVACs
      #loop through air loops
      loops.each do |loop|
        supply_components = loop.supplyComponents
        #find coils on loops
        supply_components.each do |supply_component|
          if not supply_component.to_CoilHeatingGas.empty?
            coils << supply_component.to_CoilHeatingGas.get
          end
        end   
      end      
    elsif coil_handle == 0.to_s
      #coils set to NONE so do nothing
      runner.registerInfo("Applying change to NONE Coils")
    elsif not coil_handle.empty?
      #Single coil handle found, check if object is good    
      if not coil_object.get.to_CoilHeatingGas.empty?
        runner.registerInfo("Applying change to #{coil_object.get.name.to_s} coil")
        coils << coil_object.get.to_CoilHeatingGas.get
      else
        runner.registerError("coil with handle #{coil_handle} could not be found.")
      end
    else
      runner.registerError("coil handle is empty.")
      return false
    end
       
    # report initial condition of model
    runner.registerInitialCondition("Coils to change: #{coils.size}")
    runner.registerInfo("Coils to change: #{coils.size}")
    altered_coils = []
    altered_capacity = []
    altered_parasiteelectric = []
    altered_coilefficiency = []
    altered_parasitegas = []
    # loop through coils
    coils.each do |coil|
      altered_coil = false
      # coil_capacity_multiplier
      if coil_capacity_multiplier != 1.0
        if coil.nominalCapacity.is_initialized
          runner.registerInfo("Applying #{coil_capacity_multiplier}x multiplier to #{coil.name.get}.")
          coil.setNominalCapacity(coil.nominalCapacity.get * coil_capacity_multiplier)          
          altered_capacity << coil.handle.to_s
          altered_coil = true
        end
      end
      
      # modify coil_efficiency_multiplier
      if coil_efficiency_multiplier != 1.0
        runner.registerInfo("Applying #{coil_efficiency_multiplier}x multiplier to #{coil.name.get}.")
        if coil.gasBurnerEfficiency * coil_efficiency_multiplier <= 1
          coil.setGasBurnerEfficiency(coil.gasBurnerEfficiency * coil_efficiency_multiplier)   
        else
          coil.setGasBurnerEfficiency(1.0)
          runner.registerWarning("#{coil_efficiency_multiplier}x multiplier results in Efficiency greater than 1.")
        end        
        altered_coilefficiency << coil.handle.to_s
        altered_coil = true
      end
      
      # coil_parasitic_electric_multiplier
      if coil_parasitic_electric_multiplier != 1.0
        runner.registerInfo("Applying #{coil_parasitic_electric_multiplier}x multiplier to #{coil.name.get}.")
        coil.setParasiticElectricLoad(coil.parasiticElectricLoad * coil_parasitic_electric_multiplier)          
        altered_parasiteelectric << coil.handle.to_s
        altered_coil = true
      end
      
      # coil_parasitic_gas_multiplier
      if coil_parasitic_gas_multiplier != 1.0
        runner.registerInfo("Applying #{coil_parasitic_gas_multiplier}x multiplier to #{coil.name.get}.")
        coil.setParasiticGasLoad(coil.parasiticGasLoad * coil_parasitic_gas_multiplier)          
        altered_parasitegas << coil.handle.to_s
        altered_coil = true
      end
      
      if altered_coil
        altered_coils << coil.handle.to_s
        change_name(coil,coil_parasitic_gas_multiplier,coil_efficiency_multiplier,coil_parasitic_electric_multiplier,coil_capacity_multiplier)
        runner.registerInfo("coil name changed to: #{coil.name.get}")
      end
    end #end coil loop
    
    # na if nothing in model to look at
    if altered_coils.size == 0
      runner.registerAsNotApplicable("No Coils were altered in the model")
      return true
    end

    # report final condition of model
    runner.registerFinalCondition("#{altered_coils.size} Coils objects were altered.")

    return true

  end

end

# register the measure to be used by the application
HeatingCoilsGasMultiplier.new.registerWithApplication
